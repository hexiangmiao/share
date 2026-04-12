#!/usr/bin/env python3
import sys
import csv
import re
from datetime import datetime
from pathlib import Path

def parse_log_to_csv(log_file, output_csv):
    """解析日志文件并生成CSV统计报告"""
    
    # 正则表达式编译（提高性能）
    start_pattern = re.compile(r'^Processing\s+(\S+)\s+at\s+(\S+)\s+(\S+)$')
    end_pattern = re.compile(r'^Done\s+processing\s+(\S+)\s+at\s+(\S+)\s+(\S+)$')
    
    processing = {}  # 存储开始时间
    results = []
    errors = []
    
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                
                # 匹配开始日志
                start_match = start_pattern.match(line)
                if start_match:
                    filename = start_match.group(1)
                    date_str = start_match.group(2)
                    time_str = start_match.group(3)
                    datetime_str = f"{date_str} {time_str}"
                    
                    try:
                        start_time = datetime.strptime(datetime_str, '%m/%d/%y %H:%M:%S')
                        processing[filename] = start_time
                    except ValueError as e:
                        errors.append(f"第{line_num}行时间解析失败: {datetime_str} - {e}")
                    continue
                
                # 匹配结束日志
                end_match = end_pattern.match(line)
                if end_match:
                    filename = end_match.group(1)
                    date_str = end_match.group(2)
                    time_str = end_match.group(3)
                    datetime_str = f"{date_str} {time_str}"
                    
                    if filename in processing:
                        try:
                            end_time = datetime.strptime(datetime_str, '%m/%d/%y %H:%M:%S')
                            start_time = processing[filename]
                            duration = (end_time - start_time).total_seconds()
                            
                            results.append({
                                'filename': filename,
                                'start_time': start_time.strftime('%Y-%m-%d %H:%M:%S'),
                                'end_time': end_time.strftime('%Y-%m-%d %H:%M:%S'),
                                'duration': duration,
                                'start_original': start_time.strftime('%m/%d/%y %H:%M:%S'),
                                'end_original': end_time.strftime('%m/%d/%y %H:%M:%S')
                            })
                            # 删除已处理记录，避免重复
                            del processing[filename]
                        except ValueError as e:
                            errors.append(f"第{line_num}行时间解析失败: {datetime_str} - {e}")
                    else:
                        errors.append(f"第{line_num}行: 找不到文件 {filename} 的开始记录")
    
    except FileNotFoundError:
        print(f"错误: 找不到文件 {log_file}")
        sys.exit(1)
    except Exception as e:
        print(f"错误: 读取文件失败 - {e}")
        sys.exit(1)
    
    # 检查未匹配的开始记录
    if processing:
        for filename in processing:
            errors.append(f"文件 {filename} 有开始记录但没有结束记录")
    
    # 写入CSV文件
    try:
        with open(output_csv, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['文件名', '开始时间', '结束时间', '处理时间(秒)']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            for result in results:
                writer.writerow({
                    '文件名': result['filename'],
                    '开始时间': result['start_original'],
                    '结束时间': result['end_original'],
                    '处理时间(秒)': f"{result['duration']:.2f}"
                })
    except Exception as e:
        print(f"错误: 写入CSV文件失败 - {e}")
        sys.exit(1)
    
    # 输出统计信息
    print(f"\n{'='*60}")
    print(f"处理完成！")
    print(f"{'='*60}")
    print(f"日志文件: {log_file}")
    print(f"输出文件: {output_csv}")
    print(f"成功处理: {len(results)} 个文件")
    
    if errors:
        print(f"警告/错误: {len(errors)} 条")
        print("\n详细错误信息:")
        for err in errors[:10]:  # 只显示前10条错误
            print(f"  - {err}")
        if len(errors) > 10:
            print(f"  ... 还有 {len(errors)-10} 条错误")
    
    # 显示统计摘要
    if results:
        durations = [r['duration'] for r in results]
        print(f"\n{'='*60}")
        print("统计摘要:")
        print(f"{'='*60}")
        print(f"总文件数: {len(results)}")
        print(f"总处理时间: {sum(durations):.2f} 秒 ({sum(durations)/60:.2f} 分钟)")
        print(f"平均处理时间: {sum(durations)/len(results):.2f} 秒")
        print(f"最长处理时间: {max(durations):.2f} 秒")
        print(f"最短处理时间: {min(durations):.2f} 秒")
        
        # 显示前5个文件作为预览
        print(f"\n预览前5个文件:")
        print("-" * 80)
        for i, r in enumerate(results[:5], 1):
            print(f"{i:3d}. {r['filename']:20s} {r['duration']:8.2f}秒")
    
    return results

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"用法: {sys.argv[0]} <日志文件> [输出CSV文件]")
        print(f"示例: {sys.argv[0]} app.log output.csv")
        print(f"      {sys.argv[0]} app.log  # 使用默认文件名 processing_stats.csv")
        sys.exit(1)
    
    log_file = sys.argv[1]
    output_csv = sys.argv[2] if len(sys.argv) > 2 else "processing_stats.csv"
    
    parse_log_to_csv(log_file, output_csv)
