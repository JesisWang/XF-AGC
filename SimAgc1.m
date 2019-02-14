% this is a m-file for simulation AGC control.
% wby, 2018.12.28
% ȫ�ֱ�������
clear

global Tline;   % �����ã����ڼ���ʱ�䡣
global LastAgc; % ��������ʾ��һ��AGC������ֵ���ɵ��ȸ�������λMW��
global LastPbat; % ��������ʾ��һ�δ���ָ��ֵ�����㷨��ã���λMW��
global Para;    % ������1��8��t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone���㷨������
global LastAgcLimit;%��һ��AGCָ��
global Result;  %��������������
global GenPower0;
global SOC0;    %��ʼ�ɵ�״̬
global SOC;     %�ɵ�״̬
global Prate;   %��������
global Emax;    %���ܶ����
global AAA;
global LineMax; %���ݵ����������Ҳ��ȡ���ݵ�ʱ�䳤�ȣ�
global Rall;    %
% for id=1:1:30
%     a=strcat(num2str(id),'.mat');
%     if id<10        
%         fileName=strcat('data2016120',a);
%     else
%         fileName=strcat('data201612',a);
%     end
%     load('BatData1.mat');
%     load(fileName);
load('XFdata.mat')
data=XFdata.data1209(1:end,1:3);     % �����ļ�
agcSet = 1; %agcSet=1Ϊ�д��ܼ��㣻agcSet=0Ϊ�޴����������
%data=data/600*330;
[RowNum,LineNum] = size(data);
% �����趨
LineMax = RowNum;    % 86400;
Prate = 300;        % �������ʣ�MW
Pmax = 9;         % ���ܶ���ʣ�MW
Pmin =-Pmax;
Emax = Pmax/2;    % ���ܶ������MWh
Mday = 3;           % ��������ɱ���Ԫ/W
Para = [2,200,Pmax,Pmin,(0.05*Pmax),50.0,5.0,5.0,80.0,20.0,Emax,Prate,0.01*Prate,0.005];
% t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone
% t12 �㶫100 ����100 ����200
% Phold �㶫0 ����0.05
% ������ʼ��
Result = zeros(100,23); 
Pbat = zeros(LineMax,1);
SocHist = zeros(LineMax,1);
LastAgc = 0;
LastAgcLimit = 0;
LastPbat = 0;
SOC = 50.0;
SOC0 = SOC;
Status = 99;
MoneyMax = 0;
%ParaMax = [0,0,0,0,0,0,0,0];

% ��ʷ���ݷǷ�ֵ����--Ĭ��AGCָ��ͻ��鹦��ʼ�մ��ڣ���ʵ���Բ�����-����������
for i=2:1:LineMax
    if (isnan(data(i,1))||(data(i,1)==0))
       data(i,1) = data(i-1,1);
    end
    if (isnan(data(i,2))||(data(i,2)==0))
       data(i,2) = data(i-1,2);
    end
end
Agc = data(:,1);  % ��һ��ΪAGCָ��
Pdg = data(:,2);  % �ڶ���Ϊ���������
Pall2 = data(:,3);
%data(:,4)=0;
%Pbat = data(:,4); 
%Pbat(6:LineMax) = data(1:LineMax-5,4);  % �˹���ʱ����

GenPower0 = Pdg(1);
Pall = Pdg(1); %���ܺͻ�������Ϲ���

% ģ����㿪ʼ��1sһ�μ��㣬1sһ�ε���
for i=1:1:LineMax
    Tline = i;
    if i==10950          
        test=0;
    end
    % ���ݸ���
    Pbat(i) = LastPbat;
    Pall = Pdg(i)+Pbat(i);
    if (agcSet==0)
        LastPbat = Pbat(i);
    else
        [LastPbat,Status] = BatAgcMethodMX(Agc(i),Pdg(i),Pall,SOC,0);            % AGC�㷨������
        %[LastPbat,Status] = BatAgcMethod2(Agc(i),Pdg(i),Pall,SOC,0);            % AGC�㷨��������ɽ��
        %[LastPbat,Status] = BatAgcMethodGD(Agc(i),Pdg(i),Pall,SOC,0);            % AGC�㷨���㶫
    end
    
    % �����ݸ���
    SocHist(i)= SOC;
    SOC = SOC - LastPbat/3600/Emax*100;
    SOC = min(SOC,100);  
    SOC = max(0,SOC);    
end

% ��������
%[Mall,M0all,Days] = CalMoneyMX(Agc,Pdg,Pbat);
%[Mall,M0all,Days] = CalMoneyHB(Agc,Pdg,Pbat);
%[Mall,M0all,Days] = CalMoneySX(Agc,Pdg,Pbat);
%[Mall,M0all,Days] = CalMoneyGD(Agc,Pdg,Pbat);

data(:,5) = Pbat;
data(:,4) = Pbat+Pdg;


AAA=Rall';                
% [RowNum,LineNum] = size(Result);
% n = 0;
% Kp = 0;
% for i=1:1:RowNum
%   if (Result(i,15)>0.01)
%     Kp = Kp+Result(i,15);
%     n = n+1;
%   end
% end
% Kp = Kp/n;
[Old,New]=chongzhiAGC(Agc,Pdg,data(:,4));
[Old1,New1]=chongzhiAGC(Agc,Pdg,Pall2);
% subplot(2,1,1);
% timeline = LineMax;
% plot(data(1:timeline,1),'b');hold on;
% plot(data(1:timeline,2),'g');hold on;
% plot(data(1:timeline,3),'r');hold off;
% %plot(data)
% M=(0:3600:timeline);
% T=(0:1:(timeline/3600));
% set(gca,'xtick',M);
% set(gca,'xticklabel',T);
% xlabel('time / h');
% ylabel('power / MW');
% subplot(2,1,2);
% plot(SocHist(1:timeline));
% set(gca,'xtick',M);
% set(gca,'xticklabel',T);
% xlabel('time / h');
% ylabel('SOC / %');