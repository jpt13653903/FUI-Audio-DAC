close all;
clear all;
clc;

format compact;
format long eng;

%% Min = 0x0000, Max = 0x7FFF, Res = 0x0001

% x = [0:5 10:5:90 95:100];
% y = [0 39 78 118 158 199 409 632 868 1119 1387 1675 1987 2325 2696 3106 3564 4083 4682 5391 6259 7377 8952 11640 12505 13617 15180 17836 32767];
% 
% figure; plot(x, y); grid on;
% figure; plot(x, 20*log(y/(2^15-1))); grid on;

%% Min = 0x0000, Max = 0x00FF, Res = 0x0001

% x = [0:5 10:5:90 95:100];
% y = [0 2 4 7 9 12 24 37 49 62 74 87 100 112 125 138 150 163 176 189 202 215 228 241 244 247 249 252 255];
% 
% figure; plot(x, y); grid on;
% figure; plot(x, 20*log(y/(2^8-1))); grid on;

%% 

x = 0:255;
y = linspace(-80, 0, length(x));

figure; plot(x, y); grid on;
y    = 10.^(y./20);
y(1) = 0;
figure; plot(x, y); grid on;

y = [x; round(y.*(2^16-1))];

File = fopen('Volume.mif', 'w');
 fprintf(File, '-- Auto-generated from Volume.m\n');
 fprintf(File, '\n');
 fprintf(File, 'WIDTH=16;\n');
 fprintf(File, 'DEPTH=256;\n');
 fprintf(File, 'ADDRESS_RADIX=HEX;\n');
 fprintf(File, 'DATA_RADIX=HEX;\n');
 fprintf(File, '\n');
 fprintf(File, 'CONTENT BEGIN\n');
 fprintf(File, ' %02X : %04X;\n', y);
 fprintf(File, 'END;\n');
fclose(File);
