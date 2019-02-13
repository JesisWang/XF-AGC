clc
clear
load('oridata.mat')
Pbat=oridata.data(:,1);%kW
Pdg=oridata.data(:,2);%MW
Agc=oridata.data(:,3);
Pall=oridata.data(:,4);
AgcPowergrid=oridata.AGCpowergrid;
bp=oridata.breakpoint;%1s -->breakpoints
num=length(Agc);
AGCcontainer1s=zeros(20,1);
AGCcontainer1s(1)=Agc(1);
AGClocation1s=zeros(20,1);
AGClocation1s(1)=1;
n=1;
%这是1秒扫描频率
for i=2:1:num
    if abs(Agc(i)-AGCcontainer1s(n))>AGCcontainer1s(n)*0.01
        n=n+1;
        AGCcontainer1s(n)=Agc(i);
        AGClocation1s(n)=i;
    end
end
figure(1)
stairs(AGClocation1s,AGCcontainer1s)
hold on
stairs(1:length(Agc),Agc)
figure(2)
stairs(AgcPowergrid)

%scanrate=5
AGCcontainer5s=zeros(20,1);
AGCcontainer5s(1)=Agc(1);
AGClocation5s=zeros(20,1);
AGClocation5s(1)=1;
n=1;
for i=6:5:num
    if abs(Agc(i)-AGCcontainer5s(n))>AGCcontainer5s(n)*0.01
        n=n+1;
        AGCcontainer5s(n)=Agc(i);
        AGClocation5s(n)=i;
    end
end
figure(1)
stairs(AGClocation5s,AGCcontainer5s)
hold on
stairs(1:length(Agc),Agc)
figure(2)
stairs(AgcPowergrid)

%select the AGC,because bp is the data selected by eyes in excel,not the
%real AGC.
AGCbp=zeros(length(bp),1);
AGCbplo=zeros(length(bp),1);
for i=1:length(bp)
    for j=1:length(AGClocation1s)
        if bp(i) >= AGClocation1s(j) && bp(i) < AGClocation1s(j+1)
            AGCbp(i)=AGCcontainer1s(j);
            AGCbplo(i)=AGClocation1s(j);
            break
        end
    end
end
stairs(AGCbplo,AGCbp)

load('tryAGCbp.mat')
figure(4)
stairs(tryAGCbp(:,1),'r--')
hold on
stairs(tryAGCbp(:,2),'b')
hold on
stairs(tryAGCbp(:,3),'g--')
legend('1秒扫描频率AGC','调度AGC','5秒扫描AGC')
axis([0 44 200 300]);

%analyse the abandoned data
%acquirelo is the location in 1s-data compareted with gridAGC
figure(5)
stairs(AGClocation1s,AGCcontainer1s,'b')
hold on
stairs(AGClocation1s(acquirelo),AGCcontainer1s(acquirelo),'r--')
legend('统计AGC','统计AGC中截取的对应指令')
%acquirelo is the location in 5s-data compareted with gridAGC
figure(6)
stairs(AGClocation5s,AGCcontainer5s,'b')
hold on
stairs(AGClocation5s(acquirelo5),AGCcontainer5s(acquirelo5),'r--')
legend('统计AGC','统计AGC中截取的对应指令')

figure(7)
plot(1:length(Pall),Pall)
hold on
stairs(AGClocation5s,AGCcontainer5s,'r')
hold on
stairs(AGClocation5s(acquirelo5),AGCcontainer5s(acquirelo5),'black')
legend('输出功率','AGC指令','采用的AGC指令')
figure(8)
plot(1:length(Pall),Pall,1:length(Agc),Agc)