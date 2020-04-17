# # !/bin/sh -x


DB_USER="root"
DB_PASS="vagrant"
ORCHESTRATOR_USER="orchestrator"
ORCHESTRATOR_PASS="orchestrator"
MySQLTopologyUser="orchestrator"
MySQLTopologyPass="orchestrator"
PROXYSQL_USER="proxysql"
PROXYSQL_PASS="proxysql"
REPLICATION_USER="replication"
REPLICATION_PASS="replication"
MASTER_NODE="dbnode1"

################################################################ FUNCTION START

spinner()
{
    local pid=$!
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}


provision_server() {
        SERVER_NAME=$1
	echo "I'm $SERVER_NAME"
                          echo -e  "\e[40;38;5;82mChecking pre-requisites  \e[0m\n \e[40;38;5;82m==> Percona  MySQL repository \e[0m"

                                                                 if  [ `rpm -qa percona-release|wc -l` -eq 0 ]; then
                                                                     echo -e  "\e[40;38;5;99m     * Percona repo not installed  - Started installation . \e[0m"
                                                                     sudo rm -f /etc/my.cnf
                                                                     yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm -y -q
                                                                  else
                                                                     echo -e  "\e[40;38;5;99m     * Percona repo already installed\e[0m"
                                                                  fi

                         echo -e "\e[40;38;5;82m ==> Checking MySQL server  \e[0m"
 



                         if  [ `rpm -qa Percona-Server-server-57|wc -l` -ne 0 ]; then
                                                                 echo -e  "\e[40;38;5;99m     * Observed that Percona MySQL already installed. \e[0m"
                                                                 if  [ `pidof mysqld|wc -l` -eq 0 ]; then
                                                                        echo -e  "\e[40;38;5;99m     * MySQL not running - Starting MySQL . \e[0m"
                                                                        service mysqld start
                                                                        echo -e  "  MySQL is running on PID \e[40;38;5;32m`pidof mysqld`  \e[0m"
								else
                                                                        echo -e  "  MySQL is running on PID \e[40;38;5;32m`pidof mysqld`  \e[0m"
								 fi                                         					 			 
							 
		        else
                                                                 echo -e  "\e[40;38;5;99m     * MySQL not installed \e[0m\n \e[40;38;5;99m    * Installing Mysql 5.7 from repo \e[0m "
                                                                 echo -e  "\e[40;38;5;99m     * Cleaning existing datadirectory if exists \e[0m"
                                                                 sudo rm -rf /var/lib/mysql
                                                                 yum install Percona-Server-server-57 -q -y

								 SERVER_ID=`case $SERVER_NAME in
                                                                                      	orchestrator)
                                                                                         		echo 100
                                                                                        		;;
                                                                                       	proxysql)
		                                                                                        echo 101
		                                                                                        ;;
  								     		 	dbnode1)
													echo 102
												        ;;
											dbnode2)
													echo 103
													;;
											dbnode3)
													echo 104
												        ;;
	
											dbnode4)
													echo 105
													;;
	
											     *)
													echo 1
													;;
  									     esac`
                                                                 #SERVER_ID=`hostname -i|tr '.' '\n'|tail -1`								 
                                                                 #SERVER_ID=103
                                                                 echo -e  "\e[40;38;5;82m ==> Set required MySQL variables \e[0m\n    \e[40;38;5;99m- server_id=$SERVER_ID \e[0m\n    \e[40;38;5;99m- validate_password=OFF \e[0m\n    \e[40;38;5;99m- log-bin = mysql-bin \e[0m\n    \e[40;38;5;99m- binlog_format = ROW \e[0m\n    \e[40;38;5;99m- gtid_mode = on \e[0m\n    \e[40;38;5;99m- enforce_gtid_consistency \e[0m\n    \e[40;38;5;99m- log_slave_updates  \e[0m\n    \e[40;38;5;99m- read_only=$2 \e[0m\n"
                                                                 echo -e  "\n \e[40;38;5;99m   * MySQL not running - Starting MySQL . \e[0m"
                                                                 service mysqld start
                                                                 sed  -i "/^\!includedir \/etc\/my.cnf.d\//i [mysqld]\nserver_id=$SERVER_ID\nvalidate_password=OFF\nlog-bin = mysql-bin\nbinlog_format = ROW\ngtid_mode = on\nenforce_gtid_consistency\nread_only=$2\nlog_slave_updates\ndatadir=/var/lib/mysql \nsocket=/var/lib/mysql/mysql.sock" /etc/my.cnf
                                                                 service mysqld restart
								 echo -e  " MySQL is running on PID \e[40;38;5;32m`pidof mysqld`  \e[0m"
								 sleep 5
                                                                 echo -e "\e[40;38;5;82m ==> Resetting initial MySQL root password \e[0m"
                                                                 pass=`sudo grep ' A temporary password is generated for' /var/log/mysqld.log |awk '{print $11}'|tail -1|sed "s/^[ \t]*//" `
                                                                 mysql -u$DB_USER -p"$pass" --connect-expired-password -e "SET PASSWORD = PASSWORD('vagrant');FLUSH PRIVILEGES;"
				 				 echo -e "\e[40;38;5;82m ==> Creating replication user \e[0m"
								 mysql -u$DB_USER -p"$DB_PASS" --connect-expired-password -e "GRANT REPLICATION SLAVE ON *.* TO  '$REPLICATION_USER'@'%' identified by '$REPLICATION_PASS';GRANT SELECT ON mysql.slave_master_info TO 'orchestrator'@'10.0.5.%' identified by 'orchestrator';FLUSH PRIVILEGES;"
								 echo -e "\e[40;38;5;82m ==> Creating MySQL Topology  user \e[0m"
                                                                 mysql -u$DB_USER -p"$DB_PASS" --connect-expired-password -e "GRANT SUPER, PROCESS, REPLICATION SLAVE, RELOAD ON *.* TO  '$MySQLTopologyUser'@'10.0.5.%' identified by '$MySQLTopologyPass';FLUSH PRIVILEGES;"
								 mysql -u$DB_USER -p"$DB_PASS" --connect-expired-password -e "create user 'monitor'@'10.0.5.%' identified by 'moniP@ss';Grant REPLICATION CLIENT on *.* to 'monitor'@'10.0.5.%';Flush privileges;"
								# mysql -u$DB_USER -p"$DB_PASS" --connect-expired-password -e "SET GLOBAL read_only=1;"
								 
								 
        		 fi


}


prepare_gtid()

{
        GTID=`mysql -ss -h$MASTER_NODE -ureplication -preplication -e"SHOW GLOBAL VARIABLES LIKE 'gtid_executed'"|awk '{print $2}'`
	echo -e "\e[40;38;5;82m ==> SET GTID and start replication for $1 \e[0m"
        mysql -uroot -pvagrant -e"STOP SLAVE;SET GLOBAL read_only=1;RESET MASTER;SET @@GLOBAL.GTID_PURGED='$GTID';CHANGE MASTER TO   MASTER_HOST='$MASTER_NODE', MASTER_PORT=3306,  MASTER_USER='replication', MASTER_PASSWORD='replication', MASTER_AUTO_POSITION=1;START SLAVE"

}

orchestrator_provision()

{

 echo -e "\e[40;38;5;82m ==> Checking Orchestrator \e[0m"
                              if  [ `rpm -qa orchestrator|wc -l` -ne 0 ]; then
                                     echo -e  "\e[40;38;5;99m     * Orchestator already installed . \e[0m"
                                                        if  [ `pidof orchestrator|wc -l` -eq 0 ]; then
                                                                   echo -e  "\e[40;38;5;99m     * Orchestrator not running - Starting Orchestrator . \e[0m"
                                                                   sudo service orchestrator start
                                                                   echo -e  " Orchestrator  is running on PID \e[40;38;5;32m`pidof orchestrator`  \e[0m"
                                                                   echo -e "\e[40;38;5;82m ==> Discovering nodes  \e[0m"
#                                                                   /usr/local/orchestrator/orchestrator -c discover -i 10.0.5.102:3306
                                                                    cd /usr/local/orchestrator/;/usr/local/orchestrator/orchestrator -c discover -i $MASTER_NODE:3306 cli
                                                               else
                                                                   echo -e  " Orchestrator  is running on PID \e[40;38;5;32m`pidof orchestrator`  \e[0m"
                                                                   echo -e "\e[40;38;5;82m ==> Discovering nodes  \e[0m"
#                                                                   /usr/local/orchestrator/orchestrator -c discover -i 10.0.5.102:3306
                                                                    cd /usr/local/orchestrator/;/usr/local/orchestrator/orchestrator -c discover -i $MASTER_NODE:3306 cli

                                                               fi


                              else


                               echo -e "\e[40;38;5;82m ==> Creating Orchestrator DB and USER  \e[0m"			       
                               mysql -u$DB_USER -p"$DB_PASS" --connect-expired-password -e "DROP DATABASE IF EXISTS orchestrator;CREATE DATABASE IF NOT EXISTS orchestrator;GRANT ALL PRIVILEGES ON orchestrator.* TO '$ORCHESTRATOR_USER'@'127.0.0.1' IDENTIFIED BY '$ORCHESTRATOR_PASS';FLUSH PRIVILEGES;"

                              rm -f /usr/local/orchestrator/orchestrator.conf.json
                              #sudo service orchestrator stop
                              echo -e "\e[40;38;5;82m ==> Installing Orchestrator  \e[0m"
                              rpm -i http://www6.atomicorp.com/channels/atomic/centos/7/x86_64/RPMS/oniguruma-5.9.5-3.el7.art.x86_64.rpm
                              rpm -i https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/j/jq-1.6-1.el7.x86_64.rpm
                              yum install https://github.com/github/orchestrator/releases/download/v3.0.14/orchestrator-3.0.14-1.x86_64.rpm -y -q

                              echo -e "\e[40;38;5;82m ==> Configuring Orchestrator  \e[0m"

                              cp -f /usr/local/orchestrator/orchestrator-sample.conf.json /usr/local/orchestrator/orchestrator.conf.json
                              sed -i 's/"MySQLOrchestratorUser": "orc_server_user"/"MySQLOrchestratorUser": "orchestrator"/g;s/ "MySQLOrchestratorPassword": "orc_server_password"/ "MySQLOrchestratorPassword": "orchestrator"/g;s/_intermediate_master_pattern_/*/g;s/_master_pattern_/*/g;s/"MySQLTopologyUser": "orc_client_user"/"MySQLTopologyUser": "orchestrator"/g;s/"MySQLTopologyPassword": "orc_client_password"/"MySQLTopologyPassword": "orchestrator"/g' /usr/local/orchestrator/orchestrator.conf.json



                              echo -e "\e[40;38;5;82m ==> Starting Orchestrator  \e[0m"
                              sudo service orchestrator start
			      sleep 60 
                              echo -e  " Orchestrator  is running on PID \e[40;38;5;32m`pidof orchestrator`  \e[0m"
                              echo -e "\e[40;38;5;82m ==> Discovering nodes  \e[0m"
#                             cd /usr/local/orchestrator/;/usr/local/orchestrator/orchestrator -c discover -i $MASTER_NODE:3306 cli
			      cd /usr/local/orchestrator/;/usr/local/orchestrator/orchestrator -c discover -i $MASTER_NODE:3306 cli

                       fi


}


proxysql_provsion()
{


	 echo -e "\e[40;38;5;82m ==> Checking ProxySQL \e[0m"
                              if  [ `rpm -qa proxysql|wc -l` -ne 0 ]; then
                                     echo -e  "\e[40;38;5;99m     * ProxySQL already installed . \e[0m"
                                                        if  [ `pidof proxysql|wc -l` -eq 0 ]; then
                                                                   echo -e  "\e[40;38;5;99m     * ProxySQL not running - Starting ProxySQL . \e[0m"
                                                                   sudo service proxysql start
                                                                   echo -e  " ProxySQL  is running on PID \e[40;38;5;32m`pidof proxysql`  \e[0m"
							   else
								   echo -e  " ProxySQL  is running on PID \e[40;38;5;32m`pidof proxysql`  \e[0m"                                                                                              
			                                fi




                              else
                              
                              echo -e "\e[40;38;5;82m ==> Checking ProxySQL depandancies \e[0m"
                              yum install http://mirror.centos.org/centos/7/os/x86_64/Packages/perl-DBD-MySQL-4.023-6.el7.x86_64.rpm -y -q
                              
			      echo -e "\e[40;38;5;82m ==> Installing ProxySQL  \e[0m"
			      yum install https://github.com/sysown/proxysql/releases/download/v2.0.5/proxysql-2.0.5-1-centos67.x86_64.rpm -y -q
                               
       			      echo -e "\e[40;38;5;82m ==> Starting ProxySQL  \e[0m"
                              sudo service proxysql start
                              echo -e  " ProxySQL  is running on PID \e[40;38;5;32m`pidof proxysql`  \e[0m"
                             
			      echo -e  " Installing MySQL client  \e[0m"
			      yum install https://www.percona.com/downloads/Percona-Server-5.7/Percona-Server-5.7.26-29/binary/redhat/7/x86_64/Percona-Server-client-57-5.7.26-29.1.el7.x86_64.rpm https://www.percona.com/downloads/Percona-Server-5.7/Percona-Server-5.7.26-29/binary/redhat/7/x86_64/Percona-Server-shared-57-5.7.26-29.1.el7.x86_64.rpm https://www.percona.com/downloads/Percona-Server-5.7/Percona-Server-5.7.26-29/binary/redhat/7/x86_64/Percona-Server-shared-compat-57-5.7.26-29.1.el7.x86_64.rpm -y -q
			     			   
			      #echo -e "\e[40;38;5;82m ==> Configuring ProxySQL  \e[0m"
                              echo -e "\e[40;38;5;82m ==> Add MySQL servers to ProxySQL with admin(default) user  \e[0m"
                              mysql -h 127.0.0.1 -uadmin -padmin -P6032  -e"INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (10, '10.0.5.102', 3306);INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (20, '10.0.5.103', 3306);INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (20, '10.0.5.104', 3306);INSERT INTO mysql_servers(hostgroup_id, hostname, port) VALUES (20, '10.0.5.105', 3306);LOAD MYSQL SERVERS TO RUNTIME;SAVE MYSQL SERVERS TO DISK;"
                              echo -e "\e[40;38;5;82m ==> Update the Proxysql with monitor user’s password.  \e[0m"
 			      mysql -h 127.0.0.1 -uadmin -padmin -P6032  -e"UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_username';UPDATE global_variables SET variable_value='moniP@ss' WHERE variable_name='mysql-monitor_password';LOAD MYSQL VARIABLES TO RUNTIME;SAVE MYSQL VARIABLES TO DISK;"
			      echo -e "\e[40;38;5;82m ==> Add Read/Write host groups. \e[0m"
			      mysql -h 127.0.0.1 -uadmin -padmin -P6032  -e"INSERT INTO mysql_replication_hostgroups VALUES (10,20,'read_only','Draft1');LOAD MYSQL SERVERS TO RUNTIME;SAVE MYSQL SERVERS TO DISK;"           
			      echo -e "\e[40;38;5;82m ==> Checking read flag on all MySQL Servers. \e[0m"
                              mysql -h 127.0.0.1 -uadmin -padmin -P6032  -e"select hostname, success_time_us, read_only from monitor.mysql_server_read_only_log ORDER BY time_start_us DESC limit 10;"


                       fi





}


########################################################## FUNCTION END

################ code starts here 



 case $1 in
	orchestrator)
		provision_server $1 0
                orchestrator_provision
		;;
	proxysql)
		proxysql_provsion	
		;;		
	dbnode1)
                 provision_server $1 1
                ;;
        dbnode2)
                 provision_server $1 1
		 prepare_gtid $1 
                ;;
        dbnode3)
                 provision_server $1 1
		 prepare_gtid $1
                ;;
        dbnode4)
                 provision_server $1 1
		 prepare_gtid $1
                ;;

	*)
		echo "Sorry, Something gone wrong in Vagrantfile"
		;;
  esac



