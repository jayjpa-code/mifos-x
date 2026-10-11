# Render deployment wrapper for Apache Fineract.
# The upstream image is pinned to a concrete commit-tag for repeatable dev/test deployments.
FROM apache/fineract:e7a6912a93

USER root
RUN apk add --no-cache postgresql-client
COPY render-start.sh /usr/local/bin/render-start
RUN chmod 0755 /usr/local/bin/render-start
USER nobody:nogroup

ENTRYPOINT ["/usr/local/bin/render-start"]
