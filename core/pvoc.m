function y = pvoc(x, r, n)
% y = pvoc(x, r, n)  Time-scale a signal to r times faster with phase vocoder
%      x is an input sound. n is the FFT size, defaults to 1024.  
%      Calculate the 25%-overlapped STFT, squeeze it by a factor of r, 
%      inverse spegram.
% 2000-12-05, 2002-02-13 dpwe@ee.columbia.edu.  Uses pvsample, stft, istft
% $Header: /home/empire6/dpwe/public_html/resources/matlab/pvoc/RCS/pvoc.m,v 1.3 2011/02/08 21:08:39 dpwe Exp $  

if nargin < 3
  n = 1024;
end  

% With hann windowing on both input and output, 
% we need 25% window overlap for smooth reconstruction
hop = n/4;

scf = 1.0;  


X = scf * my_stft(x', n, n, hop);  


[rows, cols] = size(X);
t = 0:r:(cols-2);

X2 = pvsample(X, t, hop);  

% Invert to a waveform
y = my_istft(X2, n, n, hop)';