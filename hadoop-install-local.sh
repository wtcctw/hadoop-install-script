#!/bin/bash


# 异常退出
exit_script(){
    exit 1
}


installWget(){
	echo 'wget....'
	cmd=`wget`
	if [ $? -ne 1 ]; then  # $? 表示上一步命令返回值
		echo '开始安装wget'
		yum -y install wget
	fi
	echo 'wget done..'
}

#关闭防火墙
stopFirewalld(){
	systemctl stop firewalld
	systemctl disable firewalld
}


########################### jdk #####################################
installJDK(){
	echo '安装jdk开始'
	java -version
	if [[ $? -ne 0 ]]; then
		ls /usr/local | grep 'jdk.*[rpm]$'
		if [ $? -ne 0 ]; then
			echo '请将jdk的rpm包放在 /usr/local 目录下!'
			exit_script
		fi
		chmod 751 /usr/local/$(ls /usr/local | grep 'jdk.*[rpm]$')
		rpm -ivh /usr/local/$(ls /usr/local | grep 'jdk.*[rpm]$')
	fi
	echo '安装jdk结束'
}

pathJDK(){
	echo '配置JAVA_HOME开始'
	grep -q "export JAVA_HOME=" /etc/profile
	if [ $? -ne 0 ]; then
		#导入配置
		filename="$(ls /usr/java | grep '^jdk.*[^rpm | gz]$' | sed -n '1p')"
		echo "export JAVA_HOME=/usr/java/$filename">>/etc/profile
		echo 'export JRE_HOME=$JAVA_HOME/jre'>>/etc/profile
		echo 'export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar'>>/etc/profile
		echo 'export PATH=$PATH:$JAVA_HOME/bin'>>/etc/profile
	fi
	source /etc/profile
	echo "JAVA_HOME=$JAVA_HOME"
	echo "JRE_HOME=$JRE_HOME"
	echo "CLASSPATH=$CLASSPATH"
	echo "PATH=$PATH"
	echo '配置JAVA_HOME结束'
}

#1、Java环境一键配置
javaInstall(){
	installJDK
	pathJDK
}


########################### hadoop用户 #####################################
#2、添加hadoop用户并设置权限
hadoopUserAdd(){
	echo '配置hadoop用户开始'
	cmd=`awk -F: '{print $1}' /etc/passwd | grep hadoop`
	if [[ $cmd = "hadoop" ]]; then
		echo '已添加过hadoop用户'
	else
		useradd hadoop
		echo '请设置hadoop用户密码....'
		passwd hadoop
		gpasswd -a hadoop root
	fi
	echo '配置hadoop用户结束'
}

########################### ssh #####################################
#3、SSH免密登录
setSSH(){
	echo '配置hadoop用户免密登录(以hadoop用户执行)开始'
	su - hadoop -c "ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa"
	su - hadoop -c "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
	su - hadoop -c "chmod 0600 ~/.ssh/authorized_keys"
	su - hadoop -c "ssh-keyscan -H localhost >> ~/.ssh/known_hosts"
	su - hadoop -c "ssh-keyscan -H 0.0.0.0 >> ~/.ssh/known_hosts"
	echo '配置hadoop用户免密登录(以hadoop用户执行)结束'
}


########################### hadoop安装 #####################################
unzipHadoop(){
	echo '解压缩hadoop压缩文件开始'
	ls /usr/local | grep 'hadoop.*[gz]$'
	if [ $? -ne 0 ]; then
		echo '请将hadoop的tar.gz包放在 /usr/local 目录下!'
		exit_script
	fi
	if [[ ! -d "/usr/local/hadoop" ]]; then
		tar -zxvf /usr/local/$(ls /usr/local | grep 'hadoop.*[gz]$') -C /usr/local
		mv /usr/local/$(ls /usr/local | grep 'hadoop.*[^gz]$') /usr/local/hadoop
		chmod 771 /usr
		chmod 771 /usr/local
		chown -R hadoop:hadoop /usr/local/hadoop
	fi
	echo '解压缩hadoop压缩文件结束'
}

pathHadoop(){
	echo '配置HADOOP_HOME及PATH开始'
	grep -q "export HADOOP_HOME=" /etc/profile
	if [ $? -ne 0 ]; then
		#导入配置
		echo 'export HADOOP_HOME=/usr/local/hadoop'>>/etc/profile
		echo 'export HADOOP_PREFIX=/usr/local/hadoop'>>/etc/profile
		echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:'>>/etc/profile
	fi
	source /etc/profile
	echo "HADOOP_HOME=$HADOOP_HOME"
	echo "HADOOP_PREFIX=$HADOOP_PREFIX"
	echo "PATH=$PATH"
	echo '配置HADOOP_HOME及PATH结束'
}

#hadoop配置文件
setHadoop(){
	echo 'hadoop配置文件改写开始'
	read -p "请输入hdfs namenode的ip:" nn_ip
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<!--
  Licensed under the Apache License, Version 2.0 (the \"License\");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an \"AS IS\" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
 
<!-- Put site-specific property overrides in this file. -->
 
<configuration>
 
	<property>
		<name>hadoop.tmp.dir</name>
		<value>file:/usr/local/hadoop/tmp</value>
		<description>指定hadoop运行时产生文件的存储路径</description>
	</property>
	<property>
		<name>fs.defaultFS</name>
		<value>hdfs://$nn_ip:9000</value>
		<description>hdfs namenode的通信地址,通信端口</description>
	</property>
 
</configuration>">$HADOOP_HOME/etc/hadoop/core-site.xml


echo '<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
 
<!-- Put site-specific property overrides in this file. -->
<!-- 该文件指定与HDFS相关的配置信息。
需要修改HDFS默认的块的副本属性，因为HDFS默认情况下每个数据块保存3个副本，
而在伪分布式模式下运行时，由于只有一个数据节点，
所以需要将副本个数改为1；否则Hadoop程序会报错。 -->
 
<configuration>
 
	<property>
		<name>dfs.replication</name>
		<value>1</value>
		<description>指定HDFS存储数据的副本数目，默认情况下是3份</description>
	</property>
	<property>
		<name>dfs.namenode.name.dir</name>
		<value>file:/usr/local/hadoop/hadoopdata/namenode</value>
		<description>namenode存放数据的目录</description>
	</property>
	<property>
		<name>dfs.datanode.data.dir</name>
		<value>file:/usr/local/hadoop/hadoopdata/datanode</value>
		<description>datanode存放block块的目录</description>
	</property>
	<property>
		<name>dfs.permissions.enabled</name>
		<value>false</value>
		<description>关闭权限验证</description>
	</property>
 
</configuration>'>$HADOOP_HOME/etc/hadoop/hdfs-site.xml
	
echo '<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
 
<!-- Put site-specific property overrides in this file. -->
<!-- 在该配置文件中指定与MapReduce作业相关的配置属性，需要指定JobTracker运行的主机地址-->
 
<configuration>
 
	<property>
		<name>mapreduce.framework.name</name>
		<value>yarn</value>
		<description>指定mapreduce运行在yarn上</description>
	</property>
	
</configuration>'>$HADOOP_HOME/etc/hadoop/mapred-site.xml

read -p "请输入yarn resourcemanager的ip:" rm_ip
echo "<?xml version=\"1.0\"?>
<!--
  Licensed under the Apache License, Version 2.0 (the \"License\");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an \"AS IS\" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->
<configuration>
 
<!-- Site specific YARN configuration properties -->
 	<property>
		<name>yarn.resourcemanager.hostname</name>
		<value>$rm_ip</value>
	</property>
	
	<property>
		<name>yarn.nodemanager.aux-services</name>
		<value>mapreduce_shuffle</value>
		<description>mapreduce执行shuffle时获取数据的方式</description>
	</property>
 
</configuration>">$HADOOP_HOME/etc/hadoop/yarn-site.xml

	#echo 'localhost'>$HADOOP_HOME/etc/hadoop/slaves
	sed -i 's/export JAVA_HOME=.*/\#&/' $HADOOP_HOME/etc/hadoop/hadoop-env.sh
	sed -i "/#export JAVA_HOME=.*/a export JAVA_HOME=$JAVA_HOME" $HADOOP_HOME/etc/hadoop/hadoop-env.sh
	chown -R hadoop:hadoop $HADOOP_HOME
	echo 'hadoop配置文件改写结束'
}

#4、单机版hadoop配置
installHadoop(){
	unzipHadoop
	pathHadoop
	setHadoop
}



########################### namenode初始化 #####################################
initHdfs(){
	echo '以hadoop用户初始化namenode'
	su - hadoop -c "hdfs namenode -format"
}


########################### 启动hadoop #####################################
startnn(){
	echo '以hadoop用户启动hdfs namenode'
	su - hadoop -c "hadoop-daemon.sh --config /usr/local/hadoop/etc/hadoop/ --script hdfs start namenode"
}

startdn(){
	echo '以hadoop用户启动hdfs datanode'
	su - hadoop -c "hadoop-daemon.sh --config /usr/local/hadoop/etc/hadoop/ --script hdfs start datanode"
}


startrm(){
	echo '以hadoop用户启动yarn resourcemanager'
	su - hadoop -c "yarn-daemon.sh --config /usr/local/hadoop/etc/hadoop/ start resourcemanager"
}

startnm(){
	echo '以hadoop用户启动yarn nodemanager'
	su - hadoop -c "yarn-daemon.sh --config /usr/local/hadoop/etc/hadoop/ start nodemanager"
}

startps(){
	echo '以hadoop用户启动yarn proxyserver'
	su - hadoop -c "yarn-daemon.sh --config /usr/local/hadoop/etc/hadoop/ start proxyserver"
}

startjh(){
	echo '以hadoop用户启动yarn jobhistory'
	su - hadoop -c "mr-jobhistory-daemon.sh --config /usr/local/hadoop/etc/hadoop/ start historyserver"	
}





########################### 安装hive #####################################
unzipHive(){
	echo '解压缩hive压缩文件开始'
	ls /usr/local | grep 'hive.*[gz]$'
	if [ $? -ne 0 ]; then
		echo '请将hive的tar.gz包放在 /usr/local 目录下!'
		exit_script
	fi
	if [[ ! -d "/usr/local/hive" ]]; then
		tar -zxvf /usr/local/$(ls /usr/local | grep 'hive.*[gz]$') -C /usr/local
		mv /usr/local/$(ls /usr/local | grep 'hive.*[^gz]$') /usr/local/hive
		chmod 771 /usr
		chmod 771 /usr/local
		chown -R hadoop:hadoop /usr/local/hive
	fi
	echo '解压缩hadoop压缩文件结束'
}

pathHive(){
	echo '配置HIVE_HOME及PATH开始'
	grep -q "export HIVE_HOME=" /etc/profile
	if [ $? -ne 0 ]; then
		#导入配置
		echo 'export HIVE_HOME=/usr/local/hive'>>/etc/profile
		echo 'export HIVE_CONF_DIR=$HIVE_HOME/conf'>>/etc/profile
		echo 'export PATH=$PATH:$HIVE_HOME/bin'>>/etc/profile
	fi
	source /etc/profile
	echo "HIVE_HOME=$HIVE_HOME"
	echo "HIVE_CONF_DIR=$HIVE_CONF_DIR"
	echo "PATH=$PATH"
	echo '配置HIVE_HOME及PATH结束'
}

setHive(){
	echo '配置hive-env.sh'
	echo "HADOOP_HOME=/usr/local/hadoop
export HIVE_CONF_DIR=/usr/local/hive/conf" > /usr/local/hive/conf/hive-env.sh
	chown hadoop:hadoop /usr/local/hive/conf/hive-env.sh

	echo '配置hive-site.xml'
	read -p "请输入mysql的ip:" mysql_ip
	read -p "请输入mysql的username:" mysql_username
	read -p "请输入mysql的password:" mysql_password
	read -p "请输入hive metastore server的ip:" hive_metastore_ip
	read -p "请输入hadoop用户的password:" hadoop_password
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?><!--
   Licensed to the Apache Software Foundation (ASF) under one or more
   contributor license agreements.  See the NOTICE file distributed with
   this work for additional information regarding copyright ownership.
   The ASF licenses this file to You under the Apache License, Version 2.0
   (the \"License\"); you may not use this file except in compliance with
   the License.  You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an \"AS IS\" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-->

<configuration>
<property>
  <name>javax.jdo.option.ConnectionURL</name>
  <value>jdbc:mysql://$mysql_ip:3306/hive_metastore?createDatabaseIfNotExist=true</value>
  <description>the URL of the MySQL database</description>
</property>

<property>
  <name>javax.jdo.option.ConnectionDriverName</name>
  <value>com.mysql.jdbc.Driver</value>
  <description>Driver class name for a JDBC metastore</description>
</property>

<property>
  <name>javax.jdo.option.ConnectionUserName</name>
  <value>$mysql_username</value>
</property>

<property>
  <name>javax.jdo.option.ConnectionPassword</name>
  <value>$mysql_password</value>
</property>

<property>
 <name>hive.metastore.warehouse.dir</name>
 <value>/usr/hive/warehouse</value>
</property>

<property>
  <name>hive.server2.thrift.client.user</name>
  <value>hadoop</value>
  <description>Username to use against thrift client</description>
</property>

<property>
  <name>hive.server2.thrift.client.password</name>
  <value>$hadoop_password</value>
  <description>Password to use against thrift client</description>
</property>

<property>
  <name>hive.metastore.uris</name>
  <value>thrift://$hive_metastore_ip:9083</value>
  <description>IP address (or fully-qualified domain name) and port of the metastore host</description>
</property>
  
</configuration>
" > /usr/local/hive/conf/hive-site.xml
	chown hadoop:hadoop /usr/local/hive/conf/hive-site.xml
	

	echo '配置hive-log4j2.properties'
	cp -f /usr/local/hive/conf/hive-log4j2.properties.template /usr/local/hive/conf/hive-log4j2.properties
	sed -i 's/.*property\.hive\.log\.dir.*/property\.hive\.log\.dir=\/usr\/local\/hive\/logs/' /usr/local/hive/conf/hive-log4j2.properties
	chown hadoop:hadoop /usr/local/hive/conf/hive-log4j2.properties
}


installHive(){
	unzipHive
	pathHive
	setHive
}

########################### 启动hive #####################################
initHiveSchema(){
	su - hadoop -c "schematool --dbType mysql --initSchema"
}

startHiveMetaStore(){
	su - hadoop -c "nohup hive --service metastore &"
}

startHiveServer2(){
	su - hadoop -c "nohup hiveserver2 &"
}




#控制台输入选项
consoleInput(){
	echo '请输入选项[1-4]'
	echo '1、java环境一键配置'
	echo '2、添加hadoop用户'
	echo '3、ssh免密登录配置(以hadoop用户执行)'
	echo '4、hadoop安装'
	echo '5、hdfs namenode format(以hadoop用户执行)'
	echo '6、启动namenode(以hadoop用户执行)'
	echo '7、启动datanode(以hadoop用户执行)'
	echo '8、启动resourcemanager(以hadoop用户执行)'
	echo '9、启动nodemanager(以hadoop用户执行)'
	echo '10、启动proxyserver(以hadoop用户执行)'
	echo '11、启动jobhistory(以hadoop用户执行)'
	echo '12、hive安装'
	echo '13、hive初始化metastore schema(以hadoop用户执行)'
	echo '14、启动metastore server(以hadoop用户执行)'
	echo '15、启动hiveserver2(以hadoop用户执行)'
	echo '请输入选项[1-11]'
	read aNum
	case $aNum in
		1)  javaInstall
		;;
		2)  hadoopUserAdd
		;;
		3)  setSSH
		;;
		4)  installHadoop
		;;
		5)  initHdfs
		;;
		6)  startnn
		;;
		7)  startdn
		;;
		8)  startrm
		;;
		9)  startnm
		;;
		10)  startps
		;;
		11)  startjh
		;;
		12)  installHive
		;;
		13)  initHiveSchema
		;;
		14)  startHiveMetaStore
		;;
		15)  startHiveServer2
		;;
		*)  echo '没有该选项，请重新输入!!!退出请按Ctrl+c'
			consoleInput
		;;
	esac
}
echo '------------------欢迎使用一键安装------------------'
echo '为保证安装过程顺利进行，请使用root用户执行该脚本'
echo '该脚本增加了本地安装包自动安装'
echo '请将安装包放在/usr/local下'
echo 'hadoop安装包要求以hadoop开头的.tar.gz包'
echo 'JDK安装包要求以jdk开头的.rpm包'
echo '----------------------------------------------------'
consoleInput