clc;
clear all;
close all;

%% parse_log.m
% 本脚本解析 log.txt 中的 OBS 与 BLH 数据，并实现如下功能：
% 1. 支持多个目标卫星（由全局变量 targetSatellites 指定）
% 2. 对 OBS 数据按卫星号分组存储
% 3. 根据 BLH 输出判断各卫星的 OBS 数据是否连续
% 4. 绘制伪距、平均 CN0 等图，同时绘制定位轨迹，
%    定位轨迹图中将经纬度转换为以全局中心点为参考的米坐标，并标注原始经纬度和高程信息
%
% 注意：BLH 行数据格式为 "纬度 经度 高程 ..."，高程为第三个数值

%% 全局变量设置
% 支持多个目标卫星（每个卫星号为字符串）
global targetSatellites;
% targetSatellites = {'01','06','08'};  % 示例，可根据需要调整
targetSatellites = {'01'};  % 示例，可根据需要调整

% 设置全局中心点（中心点经纬度及高程）
global globalCenter;
globalCenter.lat  = 39.000000;   % 中心经度（纬度）
globalCenter.lon  = 116.000000;  % 中心经度
globalCenter.elev = 312;         % 中心高程（单位：米）

%% 初始化 OBS 数据结构（字段名采用 sat<卫星号> 格式，确保合法变量名）
obsData = struct();
for i = 1:length(targetSatellites)
    fieldName = ['sat' targetSatellites{i}];
    obsData.(fieldName).st = [];
    obsData.(fieldName).spr = [];
    obsData.(fieldName).cn0_avg = [];
end

%% 初始化 BLH 数据存储变量（全局）
blh_epoch   = [];  % BLH 行中的时间标记（epoch）
blh_lat     = [];  % 纬度
blh_lon     = [];  % 经度
blh_elev    = [];  % 高程
blh_hvgdop  = [];  % 水平 GDOP（取 HVGDOP 中的第一个值）

%% 打开文件
fid = fopen('log.txt','r');
if fid == -1
    error('无法打开文件 log.txt');
end

%% 逐行读取文件，解析数据
while ~feof(fid)
    line = fgetl(fid);
    
    % 处理 OBS 行（只保留目标卫星的数据）
    if contains(line, 'Obs:SFC')
        % 提取 Obs:SFC[...] 内的内容
        obsToken = regexp(line, 'Obs:SFC\[(.*?)\]', 'tokens');
        if isempty(obsToken)
            continue;
        end
        % 将内容分割成各个字段，例如 '01', '18', '64' ...
        obs_fields = strsplit(obsToken{1}{1});
        sat_id = obs_fields{1};  % 第一字段为卫星号
        
        % 判断该卫星是否属于目标卫星
        if ~any(strcmp(targetSatellites, sat_id))
            continue;
        end
        
        % 获取对应结构体字段名
        fieldName = ['sat' sat_id];
        
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
            cn0_vals = str2num(cn0_str); %#ok<ST2NM>
            if isempty(cn0_vals)
                avg_cn0 = NaN;
            else
                avg_cn0 = mean(cn0_vals);
            end
        else
            avg_cn0 = NaN;
        end
        
        % 存储 OBS 数据
        obsData.(fieldName).st = [obsData.(fieldName).st; st_val];
        obsData.(fieldName).spr = [obsData.(fieldName).spr; spr_val];
        obsData.(fieldName).cn0_avg = [obsData.(fieldName).cn0_avg; avg_cn0];
        
    % 处理 BLH 行（对所有数据，不分卫星）
    elseif contains(line, 'BLH')
        % 提取第一个方括号内的浮点数作为 epoch
        epochToken = regexp(line, '\[\s*(\d+\.\d+)\s*\]', 'tokens');
        if ~isempty(epochToken)
            epoch_val = str2double(epochToken{1}{1});
        else
            epoch_val = NaN;
        end
        
        % 提取 HVGDOP 值，取第一个数字
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
        
        % 从冒号后提取数据（假定前3个数字分别为：纬度、经度、高程）
        parts = regexp(line, ':\s*(.*)$', 'tokens');
        if ~isempty(parts)
            data_str = parts{1}{1};
            data_parts = strsplit(strtrim(data_str));
            if length(data_parts) >= 3
                lat_val  = str2double(data_parts{1});
                lon_val  = str2double(data_parts{2});
                elev_val = str2double(data_parts{3});
            else
                lat_val  = NaN; 
                lon_val  = NaN;
                elev_val = NaN;
            end
        else
            lat_val  = NaN; 
            lon_val  = NaN;
            elev_val = NaN;
        end
        
        % 存储 BLH 数据
        blh_epoch  = [blh_epoch; epoch_val];
        blh_lat    = [blh_lat; lat_val];
        blh_lon    = [blh_lon; lon_val];
        blh_elev   = [blh_elev; elev_val];
        blh_hvgdop = [blh_hvgdop; hvgdop_val];
    end
end

% 关闭文件
fclose(fid);

%% 判断各卫星 OBS 数据是否连续（基于 BLH 输出）
% 对每颗卫星，取其 OBS st 取整后，与 BLH epoch 对比，输出缺失的 epoch
for i = 1:length(targetSatellites)
    sat_id = targetSatellites{i};
    fieldName = ['sat' sat_id];
    st_values = obsData.(fieldName).st;
    if isempty(st_values)
        fprintf('卫星 %s 无 OBS 数据。\n', sat_id);
        continue;
    end
    rounded_obs = round(st_values);
    missing_epochs = setdiff(blh_epoch, rounded_obs);
    if isempty(missing_epochs)
        fprintf('卫星 %s 的 OBS 数据连续。\n', sat_id);
    else
        fprintf('卫星 %s 的 OBS 数据不连续，缺失的 BLH epoch: %s\n', sat_id, num2str(missing_epochs'));
    end
end

%% 绘图部分

colors = lines(length(targetSatellites));  % 生成颜色
% 图1（修改版）：伪距随卫星时间变化（精确到9位小数，时间取整）
figure;
hold on;
for i = 1:length(targetSatellites)
    sat_id = targetSatellites{i};
    fieldName = ['sat' sat_id];
    
    % 取整时间
    rounded_time = round(obsData.(fieldName).st);
    
    % 伪距数据保留9位小数
    precise_spr = round(obsData.(fieldName).spr, 9);
    
    plot(rounded_time, precise_spr, 'o-', 'Color', colors(i,:), 'LineWidth', 1.5);
    
    % 标注数据点（可选）
    for j = 1:length(rounded_time)
        label = sprintf('%.9f', precise_spr(j));
        text(rounded_time(j), precise_spr(j), label, 'FontSize', 8, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', colors(i,:));
    end
end
xlabel('卫星时间 (st, 秒, 取整)');
ylabel('伪距 (Spr, 精确到9位小数)');
title('不同卫星的伪距随时间变化（精确到9位小数）');
legend(targetSatellites, 'Location', 'Best');
grid on;
hold off;

% 保存图片
saveas(gcf, 'pseudorange_vs_time_precise.png');


% 图2：平均 CN0 随卫星时间变化图（不同卫星用不同颜色）
figure;
hold on;
for i = 1:length(targetSatellites)
    sat_id = targetSatellites{i};
    fieldName = ['sat' sat_id];
    plot(obsData.(fieldName).st, obsData.(fieldName).cn0_avg, 'o-', 'Color', colors(i,:), 'LineWidth', 1.5);
end
xlabel('卫星时间 (st)');
ylabel('平均 CN0');
title('不同卫星的平均 CN0 随卫星时间变化');
legend(targetSatellites, 'Location', 'Best');
grid on;
hold off;
saveas(gcf, 'avg_cn0_vs_time_multi.png');

% 图3（修改版）：三维轨迹图（经度、纬度、时间）
figure;
plot3(blh_lon, blh_lat, blh_epoch, 'ko-', 'LineWidth', 1.5);
xlabel('经度 (°)');
ylabel('纬度 (°)');
zlabel('时间 (epoch)');
title('卫星定位三维轨迹（经纬度随时间变化）');
grid on;
view(3); % 设置为三维视角
hold on;

% 在轨迹点上标注原始数据（可选）
for j = 1:length(blh_epoch)
    label = sprintf('%.6f, %.6f\nEpoch: %.1f', blh_lat(j), blh_lon(j), blh_epoch(j));
    text(blh_lon(j), blh_lat(j), blh_epoch(j), label, 'FontSize', 8, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'Color', 'blue');
end

hold off;
saveas(gcf, 'trajectory_3D_latlon_time.png');


% 图4：水平 GDOP 随时间变化图（BLH 数据）
figure;
plot(blh_epoch, blh_hvgdop, 'o-', 'LineWidth', 1.5);
xlabel('时间标记 (epoch)');
ylabel('水平 GDOP');
title('水平 GDOP 随时间变化');
grid on;
saveas(gcf, 'hvgdop_vs_epoch.png');

% 图5：经度、纬度、高程随时间变化
figure;

subplot(3,1,1);
plot(blh_epoch, blh_lon, 'b-o', 'LineWidth', 1.5);
xlabel('时间标记 (epoch)');
ylabel('经度 (°)');
title('经度随时间变化');
grid on;

subplot(3,1,2);
plot(blh_epoch, blh_lat, 'r-o', 'LineWidth', 1.5);
xlabel('时间标记 (epoch)');
ylabel('纬度 (°)');
title('纬度随时间变化');
grid on;

subplot(3,1,3);
plot(blh_epoch, blh_elev, 'g-o', 'LineWidth', 1.5);
xlabel('时间标记 (epoch)');
ylabel('高程 (m)');
title('高程随时间变化');
grid on;

saveas(gcf, 'longitude_latitude_altitude_vs_time.png');

% 计算米坐标（相对于全局中心点）
R = 6378137;  % 地球半径（米）
delta_lat = (blh_lat - globalCenter.lat) * pi/180;
delta_lon = (blh_lon - globalCenter.lon) * pi/180;
x_meters = R * delta_lon .* cos(globalCenter.lat * pi/180); % 东向距离
y_meters = R * delta_lat; % 北向距离
z_meters = blh_elev - globalCenter.elev; % 高程差

% 绘制随时间变化的东向、北向、高程差曲线
figure;
subplot(3,1,1);
plot(blh_epoch, x_meters, 'r-', 'LineWidth', 1.5);
xlabel('时间 (epoch)');
ylabel('东向距离 (米)');
title('东向距离随时间变化');
grid on;

subplot(3,1,2);
plot(blh_epoch, y_meters, 'g-', 'LineWidth', 1.5);
xlabel('时间 (epoch)');
ylabel('北向距离 (米)');
title('北向距离随时间变化');
grid on;

subplot(3,1,3);
plot(blh_epoch, z_meters, 'b-', 'LineWidth', 1.5);
xlabel('时间 (epoch)');
ylabel('高程差 (米)');
title('高程差随时间变化');
grid on;

saveas(gcf, 'xyz_meters_vs_time.png');


