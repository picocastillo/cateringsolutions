# Put database dumps here for auto-import
#
# On FIRST `docker compose up` (empty MariaDB volume), every *.sql / *.sql.gz / *.sh
# in this folder is executed by MariaDB in alphabetical order.
#
# Recommended name for your dump:
#   docker/db/01-kiosk_development.sql
#   or: docker/db/01-kiosk_development.sql.gz
#
# Prefer dumps that include `USE kiosk_development;` (or CREATE + USE).
# Do not commit real dumps — they are gitignored.
