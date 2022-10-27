#!/bin/bash

LOG=/tmp/stack.log
ID=$(id -u)
MYSQL_URL=https://repo.mysql.com/yum/mysql-connectors-community/el/7/x86_64/mysql-community-release-el7-5.noarch.rpm 
MYSQL_RPM=$(echo $MYSQL_URL | cut -d / -f9)
SONAR_URL=https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-7.0.zip 
SONAR_ZIP=$(echo $SONAR_URL | awk -F / '{ print $NF }')
SONAR_SRC=$(echo $SONAR_URL | awk -F / '{ print $NF }' |  sed 's/.zip//')

R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[0;36m'
P='\033[0;35m'
N='\033[0;37m'

if [ $ID -ne 0 ]; then
    echo -e " $C You are not the root user, you dont have permissions to run this script $N"
    exit 1
else
    echo -e " $P You Are running Script Successfully $N"
fi

VALIDATE(){
    if [ $1 -ne 0 ]; then
       echo -e "$2 ... $R FAILED $N"
    else 
       echo -e "$2 ... $G SUCCESS $N"
   fi  
}

yum install java-1.8.0-openjdk wget unzip -y &>>$LOG
VALIDATE $? "Installing Sonar Dependences"

wget $MYSQL_URL -O /tmp/$MYSQL_RPM  &>>$LOG
VALIDATE $? "Download Mysql"

cd /tmp/
rpm -ivh mysql-community-release-el7-5.noarch.rpm &>>$LOG
yum install mysql-server -y &>>$LOG
VALIDATE $? "Installing Mysql"

systemctl start mysql
VALIDATE $? "Starting Mysql"

if [ -f /tmp/sonar.sql ]; then
    echo -e "$Y   SonarQube Database Updated! $N"
else 
    echo "CREATE DATABASE sonarqube_db;
    CREATE USER 'sonarqube_user'@'localhost' IDENTIFIED BY 'password';
    GRANT ALL PRIVILEGES ON sonarqube_db.* TO 'sonarqube_user'@'localhost' IDENTIFIED BY 'password';
    FLUSH PRIVILEGES;"  > /tmp/sonar.sql
    mysql < /tmp/sonar.sql
    VALIDATE $? "SonarQube Database Updating"
fi

egrep "sonarqube" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
   echo -e "$Y   SonarQube user exists! $N"
else 
    useradd sonarqube
    VALIDATE $? "Creating SonarQube User"
fi

if [ -d /opt/sonarqube ]; then
   echo -e "$Y   Sonar Package Exists! $N "  
else 
   wget $SONAR_URL -O /tmp/$SONAR_ZIP &>>$LOG
   VALIDATE $? "Downloading SonarQube"
fi

if [ -d /opt/sonarqube ]; then
   echo -e "$Y   Sonar DIR is Exists $N "  

else 
    unzip -o /tmp/$SONAR_ZIP   &>>$LOG
    mv $SONAR_SRC /opt/sonarqube
    chown sonarqube. /opt/sonarqube -R 
    VALIDATE $? "SonarQube Installation"
fi
echo 'sonar.jdbc.username=sonarqube_user
sonar.jdbc.password=password
sonar.jdbc.url=jdbc:mysql://localhost:3306/sonarqube_db?useUnicode=true&amp;characterEncoding=utf8&amp;rewriteBatchedStatements=true&amp;useConfigs=maxPerformance' >> /opt/sonarqube/conf/sonar.properties
VALIDATE $? "SonarQube DB Configuration"

sed -i 's/#RUN_AS_USER=/RUN_AS_USER=sonarqube/g' /opt/sonarqube/bin/linux-x86-64/sonar.sh
VALIDATE $? "Updating SonarQube Sonar.sh file"

echo "Startiing SonarQube"
sh /opt/sonarqube/bin/linux-x86-64/sonar.sh start