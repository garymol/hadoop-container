# Creates pseudo distributed hadoop 3.3.0
#
# Credit to original maintainer SequenceIQ
#
# docker build -t hadoop .

FROM fedora:34
MAINTAINER WesternSTS

USER root

# install dev tools
RUN yum clean all; \
    yum install -y curl which tar sudo openssh-server openssh-clients rsync hostname python\
    && yum clean all

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key
RUN ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# java
RUN yum install -y java-11-openjdk java-11-openjdk-devel && yum clean all
ENV JAVA_HOME /usr
ENV PATH $PATH:$JAVA_HOME/bin
RUN echo "export JAVA_HOME=/usr" >> /root/.bashrc

# hadoop
RUN curl -s https://mirror.its.dal.ca/apache/hadoop/common/hadoop-3.3.0/hadoop-3.3.0.tar.gz | tar -xz -C /usr/local/
RUN cd /usr/local && ln -s ./hadoop-3.3.0 hadoop
RUN useradd hdfs

ENV HADOOP_HOME /usr/local/hadoop
ENV HADOOP_COMMON_HOME /usr/local/hadoop
ENV HADOOP_HDFS_HOME /usr/local/hadoop
ENV HADOOP_MAPRED_HOME /usr/local/hadoop
ENV HADOOP_YARN_HOME /usr/local/hadoop
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop

RUN sed -i '/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/java/default\nexport HADOOP_HOME=/usr/local/hadoop\n:' $HADOOP_HOME/etc/hadoop/hadoop-env.sh
RUN sed -i '/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop/:' $HADOOP_HOME/etc/hadoop/hadoop-env.sh
#RUN echo -e "HDFS_DATANODE_USER=root\nHDFS_DATANODE_SECURE_USER=root\nHDFS_NAMENODE_USER=root\nHDFS_SECONDARYNAMENODE_USER=root\nYARN_RESOURCEMANAGER_USER=root\nYARN_NODEMANAGER_USER=root" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh


RUN mkdir $HADOOP_HOME/input
RUN cp $HADOOP_HOME/etc/hadoop/*.xml $HADOOP_HOME/input

# pseudo distributed
ADD core-site.xml.template $HADOOP_HOME/etc/hadoop/core-site.xml.template
RUN sed s/HOSTNAME/localhost/ /usr/local/hadoop/etc/hadoop/core-site.xml.template > /usr/local/hadoop/etc/hadoop/core-site.xml
ADD hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml
# use a slightly modified start and stop that sets the user to root:
#    http://www.continualintegration.com/miscellaneous-articles/all/how-do-you-troubleshoot-the-message-error-but-there-is-no-hdfs_datanode_user-defined/
ADD start-dfs.sh $HADOOP_HOME/sbin/start-dfs.sh
ADD start-yarn.sh $HADOOP_HOME/sbin/start-yarn.sh
ADD mapred-site.xml $HADOOP_HOME/etc/hadoop/mapred-site.xml
ADD yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml

# do this in the bootstrap, not the image
#RUN $HADOOP_HOME/bin/hdfs namenode -format

ADD ssh_config /root/.ssh/config
RUN chmod 600 /root/.ssh/config
RUN chown root:root /root/.ssh/config

ADD bootstrap.sh /etc/bootstrap.sh
RUN chown root:root /etc/bootstrap.sh
RUN chmod 700 /etc/bootstrap.sh

ENV BOOTSTRAP /etc/bootstrap.sh

# workingaround docker.io build error
RUN chmod +x /usr/local/hadoop/etc/hadoop/*-env.sh

# fix the 254 error code
RUN sed  -i "/^[^#]*UsePAM/ s/.*/#&/"  /etc/ssh/sshd_config
RUN echo "UsePAM no" >> /etc/ssh/sshd_config
RUN echo "Port 2122" >> /etc/ssh/sshd_config

# again, this is moved to the bootstrap
#RUN /usr/sbin/sshd && $HADOOP_HOME/etc/hadoop/hadoop-env.sh && $HADOOP_HOME/sbin/start-dfs.sh && $HADOOP_HOME/bin/hdfs dfs -mkdir -p /user/root
#RUN /usr/sbin/sshd && $HADOOP_HOME/etc/hadoop/hadoop-env.sh && $HADOOP_HOME/sbin/start-dfs.sh && $HADOOP_HOME/bin/hdfs dfs -put $HADOOP_HOME/etc/hadoop/ input

CMD ["/etc/bootstrap.sh", "-d"]

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 10020 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
#Other ports
EXPOSE 49707 2122
