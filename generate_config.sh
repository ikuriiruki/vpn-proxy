export $(cat .env | xargs)
envsubst < haproxy.cfg.template > haproxy.cfg
