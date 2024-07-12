
import os
import sqlalchemy
import pandas
import geopandas

engine = sqlalchemy.create_engine(
    f"postgresql://{os.environ.get('DB_USER', 'postgres')}:{os.environ.get('DB_PASS')}@"
    f"{os.environ.get('DB_HOST', 'localhost')}:{os.environ.get('DB_PORT', 5432)}/{os.environ.get('DB_NAME')}"
)

estaciones_df = pandas.read_sql(
    sqlalchemy.text("select omm_id, lon_dec, lat_dec from estacion where tipo = 'C';"), engine
)

estaciones_gdf = geopandas.GeoDataFrame(
    estaciones_df, geometry=geopandas.points_from_xy(estaciones_df.lon_dec, estaciones_df.lat_dec), crs="EPSG:4326"
)

estaciones_gdf.to_file('/tmp/estaciones.shp')
