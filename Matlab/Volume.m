close all;
clear all;
clc;

format compact;
format long eng;

%% Min = 0x0000, Max = 0x7FFF, Res = 0x0001

x = [0:5 10:5:90 95:100];
y = [0 39 78 118 158 199 409 632 868 1119 1387 1675 1987 2325 2696 3106 3564 4083 4682 5391 6259 7377 8952 11640 12505 13617 15180 17836 32767];

figure; plot(x, y); grid on;
figure; plot(x, 20*log(y/(2^15-1))); grid on;
