#!/usr/bin/env bash
#
# sqlite_simple.sh - 简化版SQLite操作库（单表）
#
# 使用方法：
#   1. 作为库导入: source sqlite_simple.sh
#   2. 设置环境变量: DB_FILE 和 SCHEMA_FILE (可选)
#   3. 调用函数: db_init, db_insert, db_query, db_update, db_delete
#

# ==================== 配置变量 ====================
# 数据库文件路径（可由调用者覆盖）
DB_FILE="${DB_FILE:-./data.db}"

# SQL schema文件路径（可由调用者覆盖）
SCHEMA_FILE="${SCHEMA_FILE:-./schema.sql}"

# ==================== 核心函数 ====================

# 检查SQLite是否可用
_check_sqlite() {
    if ! command -v sqlite3 &> /dev/null; then
        echo "错误: sqlite3 未安装，请先安装" >&2
        return 1
    fi
}

# 初始化数据库（从外部SQL文件读取表结构）
# 用法: db_init [schema_file]
# 示例: db_init                    # 使用默认 SCHEMA_FILE
#       db_init ./custom.sql       # 使用自定义文件
db_init() {
    local schema_file="${1:-$SCHEMA_FILE}"
    
    _check_sqlite || return 1
    
    # 创建数据库所在目录
    local db_dir
    db_dir=$(dirname "$DB_FILE")
    if [[ ! -d "$db_dir" ]]; then
        mkdir -p "$db_dir"
    fi
    
    # 检查schema文件
    if [[ ! -f "$schema_file" ]]; then
        echo "错误: Schema文件不存在: $schema_file" >&2
        echo "请先创建SQL文件，示例：" >&2
        cat >&2 << 'EOF'
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    age INTEGER
);
EOF
        return 1
    fi
    
    echo "正在初始化数据库: $DB_FILE"
    sqlite3 "$DB_FILE" < "$schema_file"
    echo "数据库初始化完成"
    return 0
}

# 执行SQL查询（返回结果）
# 用法: db_query "SQL语句" [是否显示表头]
# 示例: db_query "SELECT * FROM users WHERE age>25"
#       db_query "SELECT * FROM users" "header"
db_query() {
    local sql="$1"
    local show_header="${2:-}"
    
    _check_sqlite || return 1
    
    if [[ "$show_header" == "header" ]]; then
        sqlite3 -header -column "$DB_FILE" "$sql"
    else
        sqlite3 "$DB_FILE" "$sql"
    fi
}

# 执行SQL命令（INSERT/UPDATE/DELETE）
# 用法: db_exec "SQL语句"
# 示例: db_exec "INSERT INTO users(name,email,age) VALUES('Alice','alice@com',25)"
db_exec() {
    local sql="$1"
    
    _check_sqlite || return 1
    
    sqlite3 "$DB_FILE" "$sql"
    return $?
}

# 插入记录
# 用法: db_insert <values> 或 db_insert "col1,col2" "val1,val2"
# 示例: db_insert "users" "name,email,age" "'Alice','alice@com',25"
db_insert() {
    local table="$1"
    local columns="$2"
    local values="$3"
    
    _check_sqlite || return 1
    
    if [[ -z "$columns" ]] || [[ -z "$values" ]]; then
        echo "错误: 需要指定列和值" >&2
        return 1
    fi
    
    local sql="INSERT INTO $table ($columns) VALUES ($values);"
    sqlite3 "$DB_FILE" "$sql"
}

# 查询记录
# 用法: db_select <table> [where条件] [是否显示表头]
# 示例: db_select "users"                    # 查询所有
#       db_select "users" "age>25"           # 条件查询
#       db_select "users" "name='Alice'" "header"
db_select() {
    local table="$1"
    local where="$2"
    local show_header="${3:-}"
    
    local sql="SELECT * FROM $table"
    if [[ -n "$where" ]]; then
        sql="$sql WHERE $where"
    fi
    
    db_query "$sql" "$show_header"
}

# 更新记录
# 用法: db_update <table> <set_clause> <where条件>
# 示例: db_update "users" "age=26" "name='Alice'"
#       db_update "users" "email='new@com'" "id=1"
db_update() {
    local table="$1"
    local set_clause="$2"
    local where="$3"
    
    _check_sqlite || return 1
    
    if [[ -z "$set_clause" ]] || [[ -z "$where" ]]; then
        echo "错误: 需要指定SET子句和WHERE条件" >&2
        return 1
    fi
    
    local sql="UPDATE $table SET $set_clause WHERE $where;"
    sqlite3 "$DB_FILE" "$sql"
    
    local rows_affected
    rows_affected=$(sqlite3 "$DB_FILE" "SELECT changes();")
    echo "已更新 $rows_affected 条记录"
}

# 删除记录
# 用法: db_delete <table> <where条件>
# 示例: db_delete "users" "id=5"
#       db_delete "users" "age<18"
db_delete() {
    local table="$1"
    local where="$2"
    
    _check_sqlite || return 1
    
    if [[ -z "$where" ]]; then
        echo "错误: 删除操作必须指定WHERE条件（安全保护）" >&2
        echo "如需删除所有记录，请使用: db_delete_all" >&2
        return 1
    fi
    
    # 先显示将要删除的记录
    echo "将要删除以下记录："
    db_select "$table" "$where" "header"
    echo -n "确认删除？(y/N): "
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "操作已取消"
        return 0
    fi
    
    local sql="DELETE FROM $table WHERE $where;"
    sqlite3 "$DB_FILE" "$sql"
    
    local rows_affected
    rows_affected=$(sqlite3 "$DB_FILE" "SELECT changes();")
    echo "已删除 $rows_affected 条记录"
}

# 删除所有记录（清空表）
# 用法: db_delete_all <table>
db_delete_all() {
    local table="$1"
    
    local count
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table;")
    
    if [[ "$count" -eq 0 ]]; then
        echo "表已是空的"
        return 0
    fi
    
    echo "表 '$table' 共有 $count 条记录"
    echo -n "确认删除所有记录？(y/N): "
    read -r confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "操作已取消"
        return 0
    fi
    
    sqlite3 "$DB_FILE" "DELETE FROM $table;"
    sqlite3 "$DB_FILE" "VACUUM;"  # 压缩数据库
    echo "已清空表，并压缩数据库"
}

# 获取记录数
# 用法: db_count <table> [where条件]
db_count() {
    local table="$1"
    local where="$2"
    
    local sql="SELECT COUNT(*) FROM $table"
    if [[ -n "$where" ]]; then
        sql="$sql WHERE $where"
    fi
    
    sqlite3 "$DB_FILE" "$sql;"
}

# 检查记录是否存在
# 用法: db_exists <table> <where条件>
db_exists() {
    local table="$1"
    local where="$2"
    
    local count
    count=$(db_count "$table" "$where")
    [[ "$count" -gt 0 ]]
}

# 备份数据库
# 用法: db_backup [backup_file]
db_backup() {
    local backup_file="${1:-${DB_FILE}.backup}"
    
    if [[ -f "$DB_FILE" ]]; then
        cp "$DB_FILE" "$backup_file"
        echo "数据库已备份到: $backup_file"
    else
        echo "错误: 数据库文件不存在" >&2
        return 1
    fi
}

# 显示表结构
# 用法: db_schema [table]
db_schema() {
    local table="$1"
    
    if [[ -n "$table" ]]; then
        sqlite3 "$DB_FILE" ".schema $table"
    else
        sqlite3 "$DB_FILE" ".schema"
    fi
}

# 显示所有表
db_tables() {
    sqlite3 "$DB_FILE" ".tables"
}

# ==================== 导出函数 ====================
export -f db_init
export -f db_query
export -f db_exec
export -f db_insert
export -f db_select
export -f db_update
export -f db_delete
export -f db_delete_all
export -f db_count
export -f db_exists
export -f db_backup
export -f db_schema
export -f db_tables

# ==================== 命令行使用 ====================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init)
            db_init "${2:-}"
            ;;
        backup)
            db_backup "${2:-}"
            ;;
        tables)
            db_tables
            ;;
        schema)
            db_schema "${2:-}"
            ;;
        *)
            cat << 'EOF'
简化版SQLite数据库管理工具

用法:
  source $0                    # 作为库导入
  $0 init [schema_file]        # 初始化数据库
  $0 backup [backup_file]      # 备份数据库
  $0 tables                    # 显示所有表
  $0 schema [table_name]       # 显示表结构

作为库使用示例:
  source sqlite_simple.sh
  export DB_FILE="./mydb.db"
  
  # 初始化
  db_init ./schema.sql
  
  # 插入
  db_insert "users" "name,email,age" "'张三','zhang@com',25"
  
  # 查询
  db_select "users" "age>20" "header"
  
  # 更新
  db_update "users" "age=26" "name='张三'"
  
  # 删除
  db_delete "users" "id=5"
  
  # 统计
  total=$(db_count "users")
  
  # 检查存在
  if db_exists "users" "email='zhang@com'"; then
      echo "用户已存在"
  fi

环境变量:
  DB_FILE        - 数据库文件路径 (默认: ./data.db)
  SCHEMA_FILE    - Schema文件路径 (默认: ./schema.sql)
EOF
            ;;
    esac
fi
