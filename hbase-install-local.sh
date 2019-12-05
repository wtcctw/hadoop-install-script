#!/bin/bash


# 异常退出
exit_script(){
    exit 1
}


########################### 安装hbase #####################################
unzipHbase(){
	echo '解压缩hbase压缩文件开始'
	ls /usr/local | grep 'hbase.*[gz]$'
	if [ $? -ne 0 ]; then
		echo '请将hbase的tar.gz包放在 /usr/local 目录下!'
		exit_script
	fi
	if [[ ! -d "/usr/local/hbase" ]]; then
		tar -zxvf /usr/local/$(ls /usr/local | grep 'hbase.*[gz]$') -C /usr/local
		mv /usr/local/$(ls /usr/local | grep 'hbase.*[^gz]$') /usr/local/hbase
		chmod 771 /usr
		chmod 771 /usr/local
		chown -R hadoop:hadoop /usr/local/hbase
	fi
	echo '解压缩hbase压缩文件结束'
}

pathHbase(){
	echo '配置HBASE_HOME及PATH开始'
	grep -q "export HBASE_HOME=" /etc/profile
	if [ $? -ne 0 ]; then
		#导入配置
		echo 'export HBASE_HOME=/usr/local/hbase'>>/etc/profile
		echo 'export PATH=$PATH:$HBASE_HOME/bin'>>/etc/profile
	fi
	source /etc/profile
	echo "HBASE_HOME=$HBASE_HOME"
	echo "PATH=$PATH"
	echo '配置HBASE_HOME及PATH结束'
}

setHbase(){
	echo '配置hbase-env.sh'
	sed -i 's/.*JAVA_HOME.*/export JAVA_HOME=\/usr\/java\/default/' /usr/local/hbase/conf/hbase-env.sh

	echo '配置hbase-site.xml'
	read -p "请输入namenode的ip:" namenode_ip
	echo "<?xml version=\"1.0\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<!--
/**
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * \"License\"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an \"AS IS\" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
-->
<configuration>
<property>
  <name>hbase.rootdir</name>
  <value>hdfs://$namenode_ip:9000/hbase</value>
</property>

<property>
  <name>hbase.zookeeper.property.dataDir</name>
  <value>/usr/local/hbase/zookeeper_data</value>
</property>

<property>
  <name>hbase.cluster.distributed</name>
  <value>true</value>
</property>

<property>
  <name>hbase.unsafe.stream.capability.enforce</name>
  <value>false</value>
  <description>
	  Controls whether HBase will check for stream capabilities (hflush/hsync).

	  Disable this if you intend to run on LocalFileSystem, denoted by a rootdir
	  with the 'file://' scheme, but be mindful of the NOTE below.

	  WARNING: Setting this to false blinds you to potential data loss and
	  inconsistent system state in the event of process and/or node failures. If
	  HBase is complaining of an inability to use hsync or hflush it's most
	  likely not a false positive.
  </description>
</property>
</configuration>
" > /usr/local/hbase/conf/hbase-site.xml
}


installHbase(){
	unzipHbase
	pathHbase
	setHbase
}

########################### 启动hbase #####################################
startHbase(){
	su - hadoop -c "/usr/local/hbase/bin/start-hbase.sh"
}






#控制台输入选项
consoleInput(){
	echo '请输入选项[1-2]'
	echo '1、安装hbase'
	echo '2、启动hbase伪分布式(以hadoop用户执行) - HMaster, RegionServer, zookeeper三个进程，Hdfs存储'
	echo '请输入选项[1-2]'
	read aNum
	case $aNum in
		1)  installHbase
		;;
		2)  startHbase
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