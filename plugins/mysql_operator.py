from airflow.providers.mysql.hooks.mysql import MySqlHook
from support_processing import TemplateOperatorDB
import logging
from contextlib import closing
from typing import Optional, List, Any, Tuple
import pandas as pd
import os

logger = logging.getLogger(__name__)

class MySQLOperator:
    """
    Class quản lý các thao tác với MySQL database thông qua Airflow Hook.
    
    Attributes:
        mysqlhook: MySqlHook instance để kết nối database
        mysql_conn: connection object
    """
    def __init__(self, conn_id: str = "mysql"):
        """
        Khởi tạo MySQL connection
        Args: 
            conn_id: Connection ID đã cấu hình trong Airflow (default: mysql)
        """
        try:
            self.mysqlhook = MySqlHook(mysql_conn_id=conn_id)
            self.mysql_conn = self.mysqlhook.get_conn()
            logger.info(f"Successfully connected to {conn_id} database")
        except Exception as e:
            logger.error(f"Failed to connect to {conn_id} database: {str(e)}")
            raise

    def get_data_to_pd(self, query: Optional[str] = None) -> pd.DataFrame:
        """
        Lấy dữ liệu từ database và trả về Pandas DataFrame
        Args: 
            query: SQL query string
        Returns: pd.DataFrame chứa dữ liệu truy vấn được
        """
        try: 
            return self.mysqlhook.get_pandas_df(query)
        except Exception as e:
            logger.error(f"Error executing query to Dataframe: {str(e)}")
            raise

    def get_records(self, query: str) -> List[Tuple]:
        """
        Lấy dữ liệu dạng list of tuples
        Args: 
            query: SQL query string
        Returns:
            List[Tuple]: Danh sách các record
        """
        try: 
            return self.mysqlhook.get_records(query)
        except Exception as e:
            logger.error(f"Error executing query to records: {str(e)}")
            raise

    def execute_query(self, query: str) -> None:
        """
        Thực thi một SQL query (CREATE, DELETE, UPDATE, etc...)
        Args:
            query: SQL query strinng
        """
        try:
            cur = self.mysql_conn.cursor()
            cur.execute(query)
            self.mysql_conn.commit()
            logger.info(f"Successfully executed query")
        except Exception as e:
            logger.error(f"Error executing query: {str(e)}")
            raise
    
    def insert_dataframe_into_table(self, table_name: str, dataframe: pd.DataFrame, data: List[List[Any]], chunk_size: int = 100000) -> None:
        """
        Chèn dữ liệu từ DataFrame vào MySQL table theo từng chunk để tránh lỗi out of memory
        Args:
            table_name: Tên bảng cần chèn dữ liệu
            dataframe: DataFrame chứa dữ liệu cần chèn, dùng để tạo query template
            data: List of List chứa dữ liệu thực tế cần chèn, mỗi inner list là một record
            chunk_size: Số lượng record tối đa trong mỗi chunk (default: 100000)
        """
        # Tạo insert query từ DataFrame structure
        query = TemplateOperatorDB(table_name).create_query_insert_into(dataframe)
        try:
            with closing(self.mysql_conn) as conn:
                #Tắt autocomit để có thể batch commit
                if self.mysqlhook.supports_autocommit:
                    self.mysqlhook.set_autocommit(conn, False)

                with closing(conn.cursor()) as cur: 
                    # Xử lí theo từng chunk để tránh memory overflow
                    for i in range(0, len(data), chunk_size):
                        partitioned_data = data[i:i + chunk_size]

                    #Serialize từng cell để đảm bảo format đúng
                        serialized_rows = []
                        for row in partitioned_data:
                            serialized_row = [self.mysqlhook._serialize_cell(cell, conn) for cell in row]
                            serialized_rows.append(serialized_row)

                        values = tuple(serialized_rows)
                        num_records = len(values)

                        #Execute batch insert 
                        cur.executemany(query, values)
                        conn.commit()
                        logger.info(f"Merged or updated {num_records} records")

                conn.commit()
                logger.info(f"Successfully inserted all data into {table_name}")   
        except Exception as e:
            logger.error(f"Can't execute insert query: {str(e)}")
            raise
    
    def delete_records_in_table(self, table_name: str, key_field: str, values: List[Any]) -> None:
        """
        Xoá các record trong bảng dựa trên keyfield
        Args:
            table_name: Tên bảng cần xoá dữ liệu
            key_field: Tên cột dùng làm điều kiện xoá
            values: List giá trị của key_field cần xoá
        """
        query = TemplateOperatorDB(table_name).create_delete_query(key_field, values)

        try:
            with closing(self.mysql_conn) as conn: 
                if self.mysqlhook.supports_autocommit:
                    self.mysqlhook.set_autocommit(conn, False)
               
                with closing(conn.cursor()) as cur:
                    serialized_values = tuple([self.mysqlhook._serialize_cell(value, conn) for value in values])
                
                    cur.execute(query, serialized_values)
                    num_records = len(values)
                    conn.commit()
                    logger.info(f"Deleted {num_records} records from {table_name}")
            conn.commit()
        except Exception as e:
            logger.error(f"Can't execute delete query: {str(e)}")
            raise
    def insert_data_into_table(self, table_name: str, data: List[Tuple], create_table_like: str = "") -> None:
        """
        Insert dữ liệu đơn giản vào bảng.
        
        """
        # Tạo bảng nếu cần
        if create_table_like:
            create_tbl_query = (
                f"CREATE TABLE IF NOT EXISTS {table_name} "
                f"LIKE {create_table_like};"
            )
            try:
                cur = self.mysql_conn.cursor()
                cur.execute(create_tbl_query)
                self.mysql_conn.commit()
                logger.info(f"Created table {table_name} like {create_table_like}")
            except Exception as e:
                logger.error(f"Can't create table: {str(e)}")
                raise
         
        # Insert dữ liệu
        try:
            self.mysqlhook.insert_rows(table_name, data)
            logger.info(f"Successfully inserted data into {table_name}")
        except Exception as e:
            logger.error(f"Can't insert data into {table_name}: {str(e)}")
            raise

    def remove_table_if_exists(self, table_name: str) -> None:
        try:
            remove_table = f"DROP TABLE IF EXISTS {table_name};"
            cur = self.mysql_conn.cursor()
            cur.execute(remove_table)
            self.mysql_conn.commit()
            logger.info(f"Removed table: {table_name}")
        except Exception as e:
            logger.error(f"Can't remove table {table_name}: {str(e)}")
            raise

    
    def truncate_all_data_from_table(self, table_name: str) -> None:
        """
        Xóa toàn bộ dữ liệu trong bảng (giữ lại cấu trúc bảng).
        """
        try:
            truncate_table = f"TRUNCATE TABLE {table_name};"
            cur = self.mysql_conn.cursor()
            cur.execute(truncate_table)
            self.mysql_conn.commit()
            logger.info(f"Truncated all data from: {table_name}")
        except Exception as e:
            logger.error(f"Can't truncate data from {table_name}: {str(e)}")
            raise

    def dump_table_into_path(self, table_name: str) -> None:
        """
        Export bảng ra file text sử dụng bulk_dump.
        Note:
            File sẽ được lưu ở thư mục secure_file_priv của MySQL
            Tên file: <table_name>.txt (dấu . được thay bằng __)
        Example:
            >>> ops.dump_table_into_path('mydb.users')
            >>> # Tạo file: /var/lib/mysql-files/mydb__users.txt
        """
        try:
            #Lấy secure file priv path
            priv = self.mysqlhook.get_first("SELECT @@global.secure_file_priv")
            if priv and priv[0]:
                tbl_name = str(table_name)
                # Thay . bằng __ để tránh vấn đề với file name
                file_name = tbl_name.replace(".", "__")
                file_path = os.path.join(priv[0], f"{file_name}.txt")
                self.mysqlhook.bulk_dump(tbl_name, file_path)
                logger.info(f"Dumped {table_name} to {file_path}")
            else:
                raise Exception("Missing secure_file_priv privilege")
        except Exception as e:
            logger.error(f"Can't dump table {table_name} into path: {str(e)}")
            raise

    def load_data_into_table(self, table_name: str, file_name: str = "TABLES.txt") -> None:
        """
            Load dữ liệu từ file vào bảng sử dụng LOAD DATA INFILE.
        Args:
            table_name: Tên bảng đích
            file_name: Tên file cần load (default: "TABLES.txt")
            
        Note:
            File phải nằm trong thư mục secure_file_priv của MySQL
            
        Example:
            >>> ops.load_data_into_table('users', 'users_backup.txt')
        """

        try:
            # Lấy secure_file_priv path
            priv = self.mysqlhook.get_first("SELECT @@global.secure_file_priv")
            
            if priv and priv[0]:
                file_path = os.path.join(priv[0], file_name)
                load_data_into_tbl = (
                    f"LOAD DATA INFILE '{file_path}' "
                    f"INTO TABLE {table_name};"
                )
                
                cur = self.mysql_conn.cursor()
                cur.execute(load_data_into_tbl)
                self.mysql_conn.commit()
                logger.info(f"Loaded data from {file_path} into {table_name}")
            else:
                raise Exception("Missing secure_file_priv privilege")
                
        except Exception as e:
            logger.error(f"Can't load data into {table_name}: {str(e)}")
            raise
    
    def __enter__(self):
        """Context manager support - enter"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager support - exit"""
        if self.mysql_conn:
            self.mysql_conn.close()
            logger.info("MySQL connection closed")
 