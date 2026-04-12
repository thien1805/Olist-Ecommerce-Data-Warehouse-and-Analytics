# 1. Import file .env
# Dấu trừ '-' phía trước giúp Makefile không báo lỗi nếu file .env chưa tồn tại
-include .env

# 2. Export tất cả các biến đã load từ .env vào shell môi trường
export

# Định nghĩa các Targets
to_mysql:
	docker exec -it mysql mysql -u"$(MYSQL_USER)" -p"$(MYSQL_PASSWORD)" $(MYSQL_DATABASE)

to_mysql_root:
	docker exec -it mysql mysql -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" $(MYSQL_DATABASE)

mysql_create:
	docker exec -it mysql mysql --local_infile -u"$(MYSQL_USER)" -p"$(MYSQL_PASSWORD)" $(MYSQL_DATABASE) -e"source /tmp/load_dataset/olist.sql"

mysql_load:
	docker exec -it mysql mysql --local_infile=1 -u"$(MYSQL_USER)" -p"$(MYSQL_PASSWORD)" $(MYSQL_DATABASE) -e"source /tmp/load_dataset/load_data.sql"