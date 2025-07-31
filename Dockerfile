FROM google/cloud-sdk:slim

RUN apt-get update && apt-get install -y jq && apt-get clean

COPY deploy.sh /usr/local/bin/deploy.sh
RUN chmod +x /usr/local/bin/deploy.sh

ENTRYPOINT ["/usr/local/bin/deploy.sh"]

