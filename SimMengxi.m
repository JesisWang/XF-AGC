% 全局变量定义
clear

global T             % 全局时间
global lastPdg       % 上一时刻的储能出力
global lastPall      % 上一时刻的联合出力
global LastAgc
global AgcStart
global Pdg_record
global T_record
global flag

load('XFdata.mat')
data=XFdata.data1205(1:end,1:3);
Agc=data(:,1);% AGC指令
Pdg=data(:,2);% 机组出力
Pall3=data(:,3);% 实际的联合出力
Pdg_record=zeros(3600,1);
LineMax=length(Agc);
SOCini=50;
Emax=9;
SOC=zeros(LineMax,1);
Pbat=zeros(LineMax,1);
Pall=zeros(LineMax,1);
SOC(1)=SOCini;
for i=1:LineMax
    T=i;
    if T==1
        lastPdg=0;
        lastPall=0;
        LastAgc=0;
        AgcStart=0;
        T_record=0;
        flag=0;
        lastSOC=SOCini;
        lastPbat=0;
    else
        lastSOC=SOC(i-1);
    end
    % 数据更新
    Pbat(i) = lastPbat;
    Pall(i) = Pdg(i)+Pbat(i);
    if i<=3600
        Pdg_record(i)=Pdg(i);
    else
        if Pdg_record(3600)~=0
            Pdg_record(1)=[];
            Pdg_record(3600)=Pdg(i);
        end
    end
    [lastPbat,Status] = ControlMethod(Agc(i),Pdg(i),lastSOC);            % AGC算法，华北、山西
%     [LastPbat,Status] = BatAgcMethodMX(Agc(i),Pdg(i),Pall(i),SOC,0);
    % 总数据更新
    if T==1
        SOC(i)=SOCini-lastPbat/3600/Emax*100;
    else
        SOC(i)=SOC(i-1)-lastPbat/3600/Emax*100;
    end
    SOC = min(SOC,100);  
    SOC = max(0,SOC);    
end
[Old,New]=chongzhiAGC(Agc,Pdg,Pall);
% Result=Rall;
% Result=[k1 k2 k3 kp D Income/万元 电池成本 能量]
%%% 计算跑点
Q=0;
for i=1:288
    m=sum(Agc((i-1)*300+1:i*300));
    n=sum(Pall((i-1)*300+1:i*300));
    if n<m*0.98 || n>m*1.02
        Q=Q+1;
        i;
    end
end
% Q
[Old1,New1]=chongzhiAGC(Agc,Pdg,Pall3);
% Result2=Rall;
%%% 计算跑点
Q=0;
for i=1:288
    m=sum(Agc((i-1)*300+1:i*300));
    n=sum(Pall3((i-1)*300+1:i*300));
    if n<m*0.98 || n>m*1.02
        Q=Q+1;
        i;
    end
end
% Q