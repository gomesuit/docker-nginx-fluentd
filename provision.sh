#!/bin/sh

curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent2.sh | sh
td-agent-gem install fluent-plugin-forest
td-agent-gem install fluent-plugin-rewrite-tag-filter

tee /etc/td-agent/td-agent.conf <<-EOF
<source>
  type forward
  port 24224
  bind 0.0.0.0
</source>

<match docker.**>
  type copy
  <store>
    type stdout
  </store>
  <store>
    type rewrite_tag_filter
    rewriterule1 source stderr stderr.__TAG__
    rewriterule2 source stdout stdout.__TAG__
  </store>
</match>

<match {stdout,stderr}.docker.**>
  type forest
  subtype copy

  <template>
    <store>
      type stdout
    </store>

    <store>
      type file
      path /var/log/td-agent/messages/__TAG_PARTS[0]__.log
      time_slice_format %Y%m%d
      time_format %Y%m%dT%H%M%S%z
      flush_interval 5s
      time_slice_wait 20s
    </store>
  </template>
</match>

EOF

/etc/init.d/td-agent start


curl -fsSL https://get.docker.com/ | sh

systemctl enable docker
systemctl start docker

docker run -d --name nginx -p 80:80 \
  --log-driver=fluentd \
  --log-opt=fluentd-address=192.168.33.10:24224 \
  --log-opt=fluentd-tag=docker.nginx.{{.ID}} \
  nginx

