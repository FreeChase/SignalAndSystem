clc;
clear all;
close all;

%% parse_log.m
% 解析日志文件 log.txt 中的 Obs 与 BLH 数据，并生成图表
% 仅处理指定卫星号（targetSatellite）的 Obs 数据
% 图3中同时显示经纬度转换成的米坐标以及原始经纬度

% 定义全局变量，用于指定目标卫星号（例如 '01'）
global targetSatellite;
targetSatellite = '01';

% 打开文件
fid = fopen('log.txt','r');
if fid == -1
    error('无法打开文件 log.txt');
end

% 初始化数据存储变量
obs_st = [];        % 卫星时间 (st)
obs_spr = [];       % 伪距 (Spr)
obs_cn0_avg = [];   % 平均 CN0

blh_epoch = [];     % 时间标记（epoch）
blh_lat = [];       % 纬度
blh_lon = [];       % 经度
blh_hvgdop = [];    % 水平 GDOP（取 HVGDOP 中的第一个值）

% 逐行读取文件
while ~feof(fid)
    line = fgetl(fid);
    
    % 处理 Obs 行，只读取目标卫星的观测数据
    if contains(line, 'Obs:SFC')
        % 提取 Obs:SFC[...] 内的内容
        obsToken = regexp(line, 'Obs:SFC\[(.*?)\]', 'tokens');
        if isempty(obsToken)
            continue;
        end
        % 将内容分割成各个字段
        obs_fields = strsplit(obsToken{1}{1});
        % 检查第一个字段是否匹配目标卫星号
        global targetSatellite;
        if ~strcmp(obs_fields{1}, targetSatellite)
            continue;  % 如果不是目标卫星，则跳过
        end
        
        % 提取卫星时间 st
        stToken = regexp(line, 'st\s+([\d\.]+)', 'tokens');
        if ~isempty(stToken)
            st_val = str2double(stToken{1}{1});
        else
            st_val = NaN;
        end
        
        % 提取伪距 Spr
        sprToken = regexp(line, 'Spr:\s+([\d\.\-]+)', 'tokens');
        if ~isempty(sprToken)
            spr_val = str2double(sprToken{1}{1});
        else
            spr_val = NaN;
        end
        
        % 提取 CN0s 数据，并计算平均值
        cn0Token = regexp(line, 'CN0s\[(.*?)\]', 'tokens');
        if ~isempty(cn0Token)
            cn0_str = cn0Token{1}{1};
            % 使用 str2num 将字符串转换为数值数组
            cn0_vals = str2num(cn0_str); %#ok<ST2NM>
            if isempty(cn0_vals)
                avg_cn0 = NaN;
            else
                avg_cn0 = mean(cn0_vals);
            end
        else
            avg_cn0 = NaN;
        end
        
        % 存储 Obs 数据
        obs_st = [obs_st; st_val];
        obs_spr = [obs_spr; spr_val];
        obs_cn0_avg = [obs_cn0_avg; avg_cn0];
        
    % 处理 BLH 行（不做卫星号过滤）
    elseif contains(line, 'BLH')
        % 提取第一个方括号内的浮点数作为 epoch
        epochToken = regexp(line, '\[\s*(\d+\.\d+)\s*\]', 'tokens');
        if ~isempty(epochToken)
            epoch_val = str2double(epochToken{1}{1});
        else
            epoch_val = NaN;
        end
        
        % 提取 HVGDOP 值（格式：HVGDOP[ 数字 数字 数字 ]），取第一个数字
        hvgdopToken = regexp(line, 'HVGDOP\[\s*([\d\.\-\s]+)\]', 'tokens');
        if ~isempty(hvgdopToken)
            hvgdop_str = hvgdopToken{1}{1};
            hvgdop_vals = str2num(hvgdop_str); %#ok<ST2NM>
            if ~isempty(hvgdop_vals)
                hvgdop_val = hvgdop_vals(1);
            else
                hvgdop_val = NaN;
            end
        else
            hvgdop_val = NaN;
        end
        
        % 从冒号后提取数据（假定前3个数字分别为：纬度、经度、高度）
        parts = regexp(line, ':\s*(.*)$', 'tokens');
        if ~isempty(parts)
            data_str = parts{1}{1};
            data_parts = strsplit(strtrim(data_str));
            if length(data_parts) >= 3
                lat_val = str2double(data_parts{1});
                lon_val = str2double(data_parts{2});
            else
                lat_val = NaN; lon_val = NaN;
            end
        else
            lat_val = NaN; lon_val = NaN;
        end
        
        % 存储 BLH 数据
        blh_epoch = [blh_epoch; epoch_val];
        blh_lat = [blh_lat; lat_val];
        blh_lon = [blh_lon; lon_val];
        blh_hvgdop = [blh_hvgdop; hvgdop_val];
    end
end

% 关闭文件
fclose(fid);

%% 绘图

% 图1：伪距随卫星时间变化图
figure;
plot(obs_st, obs_spr, 'o-');
xlabel('卫星时间 (st)');
ylabel('伪距 (Spr)');
title(['卫星号 ' targetSatellite ' 的伪距随卫星时间变化']);
grid on;
saveas(gcf, 'pseudorange_vs_time.png');

% 图2：平均 CN0 随卫星时间变化图
figure;
plot(obs_st, obs_cn0_avg, 'o-');
xlabel('卫星时间 (st)');
ylabel('平均 CN0');
title(['卫星号 ' targetSatellite ' 的平均 CN0 随卫星时间变化']);
grid on;
saveas(gcf, 'avg_cn0_vs_time.png');

% 图3：定位轨迹（经纬度转换为米后绘图，同时标注米和经纬度）
if ~isempty(blh_lat) && ~isempty(blh_lon)
    % 选择第一个点作为参考点
    ref_lat = blh_lat(1);
    ref_lon = blh_lon(1);
    R = 6378137; % 地球半径（米）
    
    % 计算纬度、经度的差值（转换为弧度）
    delta_lat = (blh_lat - ref_lat) * pi/180;
    delta_lon = (blh_lon - ref_lon) * pi/180;
    
    % 转换为米（经度距离需要乘以 cos(参考纬度)）
    x = R * delta_lon .* cos(ref_lat * pi/180);
    y = R * delta_lat;
    
    figure;
    plot(x, y, 'o-', 'LineWidth', 1.5);
    xlabel('东向距离 (米)');
    ylabel('北向距离 (米)');
    title('定位轨迹（米坐标）及对应经纬度');
    grid on;
    hold on;
    
    % 循环添加标注：同时显示米坐标和经纬度（经度、纬度）
    for i = 1:length(x)
        % 格式：米坐标 (x, y) 和 经纬度 (lat, lon)
        label = sprintf('M:(%.0f,%.0f)\nLL:(%.4f,%.4f)', x(i), y(i), blh_lat(i), blh_lon(i));
        text(x(i), y(i), label, 'FontSize', 8, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', 'blue');
    end
    hold off;
    saveas(gcf, 'trajectory_meters_with_latlon.png');
end

% 图4：水平 GDOP 随时间变化图
figure;
plot(blh_epoch, blh_hvgdop, 'o-');
xlabel('时间标记 (epoch)');
ylabel('水平 GDOP');
title('水平 GDOP 随时间变化');
grid on;
saveas(gcf, 'hvgdop_vs_epoch.png');
