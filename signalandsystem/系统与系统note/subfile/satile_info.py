#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
示例：解析日志数据，自动分析定位精度、卫星伪距、卫星时间，并画图

请先将日志数据保存为 log.txt 文件，然后运行此脚本。
"""

import re
import matplotlib.pyplot as plt

def parse_obs_line(line):
    """
    解析 Obs 行，提取：
      - 卫星标识信息（Obs:SFC[...] 内的内容）
      - st: 卫星时间
      - Spr: 卫星伪距
      - CN0s: 信噪比列表
    """
    obs_match = re.search(r'Obs:SFC\[(.*?)\]', line)
    st_match = re.search(r'st\s+([\d\.]+)', line)
    spr_match = re.search(r'Spr:\s+([\d\.\-]+)', line)
    cn0_match = re.search(r'CN0s\[(.*?)\]', line)
    
    satellite_info = obs_match.group(1) if obs_match else None
    st = float(st_match.group(1)) if st_match else None
    spr = float(spr_match.group(1)) if spr_match else None
    cn0s = []
    if cn0_match:
        cn0_values = cn0_match.group(1).split()
        try:
            cn0s = [float(val) for val in cn0_values]
        except ValueError:
            cn0s = []
    return {
        'satellite_info': satellite_info,
        'st': st,
        'spr': spr,
        'cn0s': cn0s,
    }

def parse_blh_line(line):
    """
    解析 BLH 行，提取：
      - epoch：用第一个遇到的浮点数（通常为时间标记，如 [ 450385.0 ]）
      - ErrENU 数值（定位误差相关数据）
      - HVGDOP 数值（水平/垂直 GDOP 信息）
      - 后面冒号后的数据，其中前 3 个数字作为经纬度和高度
    """
    # 提取第一个浮点数（时间标记）
    epoch_match = re.search(r'\[\s*(\d+\.\d+)\s*\]', line)
    epoch = float(epoch_match.group(1)) if epoch_match else None
    
    # 提取 ErrENU 值（如果需要定位误差，可参考此数据）
    err_match = re.search(r'ErrENU\[\s*([\d\.\-\s]+)\]', line)
    err_values = []
    if err_match:
        try:
            err_values = [float(x) for x in err_match.group(1).split()]
        except ValueError:
            err_values = []
    # 提取 HVGDOP 值（通常为3个数字，如水平、垂直、综合GDOP）
    hvgdop_match = re.search(r'HVGDOP\[\s*([\d\.\-\s]+)\]', line)
    hvgdop_values = []
    if hvgdop_match:
        try:
            hvgdop_values = [float(x) for x in hvgdop_match.group(1).split()]
        except ValueError:
            hvgdop_values = []
    # 冒号后的数据（以空格分隔，假定前3个数字为：纬度、经度、高度）
    try:
        after_colon = line.split(':')[-1].strip()
        parts = after_colon.split()
        lat = float(parts[0]) if len(parts) > 0 else None
        lon = float(parts[1]) if len(parts) > 1 else None
        height = float(parts[2]) if len(parts) > 2 else None
    except Exception:
        lat, lon, height = None, None, None

    return {
        'epoch': epoch,
        'err_enu': err_values,
        'hvgdop': hvgdop_values,
        'lat': lat,
        'lon': lon,
        'height': height,
    }

def main():
    # 存储解析后的数据
    obs_data = []
    blh_data = []
    
    # 请确保日志文件 log.txt 与此脚本在同一目录下
    with open('log.txt', 'r', encoding='utf-8') as f:
        for line in f:
            if 'Obs:SFC' in line:
                data = parse_obs_line(line)
                obs_data.append(data)
            elif 'BLH' in line:
                data = parse_blh_line(line)
                blh_data.append(data)
    
    # ---------------------------
    # 图1：伪距（Spr）随时间变化图
    obs_times = [d['st'] for d in obs_data if d['st'] is not None and d['spr'] is not None]
    spr_values = [d['spr'] for d in obs_data if d['st'] is not None and d['spr'] is not None]
    plt.figure(figsize=(10, 6))
    plt.plot(obs_times, spr_values, marker='o', linestyle='-')
    plt.xlabel('卫星时间 (st)')
    plt.ylabel('伪距 (Spr)')
    plt.title('伪距随卫星时间变化')
    plt.grid(True)
    plt.savefig('pseudorange_vs_time.png')
    plt.show()
    
    # ---------------------------
    # 图2：平均 CN0 随时间变化图
    cn0_avg = []
    cn0_times = []
    for d in obs_data:
        if d['st'] is not None and d['cn0s']:
            avg = sum(d['cn0s']) / len(d['cn0s'])
            cn0_avg.append(avg)
            cn0_times.append(d['st'])
    plt.figure(figsize=(10, 6))
    plt.plot(cn0_times, cn0_avg, marker='o', linestyle='-')
    plt.xlabel('卫星时间 (st)')
    plt.ylabel('平均 CN0')
    plt.title('平均 CN0 随卫星时间变化')
    plt.grid(True)
    plt.savefig('avg_cn0_vs_time.png')
    plt.show()
    
    # ---------------------------
    # 图3：定位轨迹（经纬度图）
    blh_epochs = [d['epoch'] for d in blh_data if d['lat'] is not None and d['lon'] is not None]
    lats = [d['lat'] for d in blh_data if d['lat'] is not None and d['lon'] is not None]
    lons = [d['lon'] for d in blh_data if d['lat'] is not None and d['lon'] is not None]
    plt.figure(figsize=(8, 8))
    plt.plot(lons, lats, marker='o', linestyle='-')
    plt.xlabel('经度')
    plt.ylabel('纬度')
    plt.title('定位轨迹（经纬度）')
    plt.grid(True)
    plt.savefig('trajectory.png')
    plt.show()
    
    # ---------------------------
    # 图4：水平 GDOP 随时间变化图（取 HVGDOP 中的第一个数值作为水平 GDOP）
    if blh_data and all(d['hvgdop'] for d in blh_data):
        hvgdop_first = [d['hvgdop'][0] for d in blh_data]
        blh_epochs_valid = [d['epoch'] for d in blh_data if d['hvgdop']]
        plt.figure(figsize=(10, 6))
        plt.plot(blh_epochs_valid, hvgdop_first, marker='o', linestyle='-')
        plt.xlabel('时间标记 (epoch)')
        plt.ylabel('水平 GDOP')
        plt.title('水平 GDOP 随时间变化')
        plt.grid(True)
        plt.savefig('hvgdop_vs_epoch.png')
        plt.show()

if __name__ == '__main__':
    main()
