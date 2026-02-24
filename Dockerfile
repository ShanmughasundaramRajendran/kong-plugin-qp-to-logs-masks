FROM kong:latest

USER root

ENV KONG_PLUGINS=bundled,qp-to-logs-masks
