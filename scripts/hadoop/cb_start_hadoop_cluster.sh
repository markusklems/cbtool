#!/usr/bin/env bash

#/*******************************************************************************
# Copyright (c) 2012 IBM Corp.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#/*******************************************************************************

source $(echo $0 | sed -e "s/\(.*\/\)*.*/\1.\//g")/cb_hadoop_common.sh
START=`provision_application_start`

syslog_netcat "Starting Hadoop cluster on master ${hadoop_master_ip} with slaves ${slave_ips_csv} (my ip is ${my_ip_addr})"

#start mapreduce
if [ x"$my_role" == x"hadoopmaster" ]; then
	syslog_netcat "....Formating namenode...."
	${HADOOP_HOME}/bin/hadoop namenode -format

	syslog_netcat "....starting hadoop services...."
	syslog_netcat "....starting primary NameNode...."
	${HADOOP_HOME}/bin/start-dfs.sh
	syslog_netcat "....starting JobTracker...."
	${HADOOP_HOME}/bin/start-mapred.sh
#	${HADOOP_HOME}/bin/start-all.sh
fi

syslog_netcat "Waiting for all Datanodes to become available....."
while [ z${DATANODES_AVAILABLE} != z"true" ]
do
    DFSADMINOUTPUT=`${HADOOP_HOME}/bin/hadoop dfsadmin -report | grep "Datanodes available"`
    AVAILABLE_NODES=`echo ${DFSADMINOUTPUT} | cut -d ":" -f 2 | cut -d " " -f 2`
    TOTAL_NODES=`echo ${DFSADMINOUTPUT} | cut -d ":" -f 2 | cut -d " " -f 3 | sed 's/(//g'`
	if [[ ${AVAILABLE_NODES} -ne 0 && z${AVAILABLE_NODES} == z${TOTAL_NODES} ]]
    then
        DATANODES_AVAILABLE="true"
    else
        DATANODES_AVAILABLE="false"
    fi
    sleep 1
done
syslog_netcat "All Datanodes (${TOTAL_NODES}) available now"

#Prepare input data for the hadoop execution
#Run teragen!

if [ x"$my_role" == x"hadoopmaster" ]; then

	dont_generate_input_data=`get_my_ai_attribute dont_generate_input_data`
	dont_generate_input_data=`echo ${dont_generate_input_data} | tr '[:upper:]' '[:lower:]'`

	if [ "${dont_generate_input_data}" = "true" ]
	then
		syslog_netcat "AI parameter \"dont_generate_input_data\" set to \"true\". No input data will be generated (useful for diagnostic purposes)"
	else
		for key in "${!tab_LOAD_LEVEL_geninput[@]}"
		do
			syslog_netcat "....Generating input by running the command \"${jar_command} ${tab_LOAD_LEVEL_geninput[$key]} \"...."
			$jar_command ${tab_LOAD_LEVEL_geninput[$key]} 2>&1 | while read line; do
				syslog_netcat "$line"
			done
			syslog_netcat "......Done......"
		done
	fi
fi
syslog_netcat "......exit......"
provision_application_stop $START
exit 0