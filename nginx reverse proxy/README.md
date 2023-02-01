:bangbang: Project Evaluation :bangbang:

This nginx reverse proxy settings allows only api key authentication !

Service available:

:white_check_mark: Sending logs from Elastic-Agent to Elasticsearch Node API /_bulk

:white_check_mark: Checkin to Fleet 

:white_check_mark: Elastic-Agent Policy Changes 

:question: Agent Rollout



HTTP Header looks like this ...

curl -H "Authorization: ApiKey VnVhQ2ZHY0JDZGJrUW0tZTVhT3g6dWkybHAyYXhUTm1zeWFrdzl0dk5udw==" \
http://localhost:9200/_cluster/health\?pretty 


This is not tested for fleet enrollment, only for enrolled elastic-agents.

Certificate Alt. Name for Proxy must match both Server ( Fleet-Server & Proxy ) !


NGINX Logs shows 200 OK

10.0.66.11 - - [01/Feb/2023:20:56:52 +0000] "POST /api/fleet/agents/085cd50d-bf0b-426d-1e68-e4cc2b190d11/checkin? HTTP/1.1" 200 20 "-" "Elastic Agent v8.6.1" "-"

10.0.20.10 - - [31/Jan/2023:21:21:46 +0000] "POST /_bulk HTTP/1.1" 200 535 "-" "Elastic-filebeat/8.6.1 (linux; amd64; 14f2f8df85f8c310945feee783771bd742cd6b2d; 2023-01-24 13:28:02 +0000 UTC)" "-"
