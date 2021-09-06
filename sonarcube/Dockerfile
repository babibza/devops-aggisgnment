FROM java:openjdk-7-jdk
MAINTAINER Marcus Autenrieth mautenrieth@poe.de

RUN apt-get update --fix-missing && apt-get install wget

ENV version 5.0.1

ADD http://dist.sonar.codehaus.org/sonarqube-${version}.zip sonarqube.zip

RUN unzip sonarqube.zip -d /opt && \
    mv /opt/sonarqube-${version} /opt/sonarqube

VOLUME /opt/sonarqube/conf/
VOLUME /opt/sonarqube/extensions/plugins

RUN chmod +x /opt/sonarqube/bin/linux-x86-64/sonar.sh

EXPOSE 9000

CMD ["/opt/sonarqube/bin/linux-x86-64/sonar.sh", "console"]
