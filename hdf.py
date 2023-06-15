
import sys
import numpy as np
import rioxarray as rxr


# https://e4ftl01.cr.usgs.gov/MOLT/MOD13A2.006/2019.01.01/MOD13A2.A2019001.h12v11.006.2019024152520.hdf
# https://e4ftl01.cr.usgs.gov/MOLT/MOD13A2.061/2019.01.01/MOD13A2.A2019001.h12v11.061.2020286125500.hdf

# Ejemplo de lectura de URL (https://stackoverflow.com/q/58089186)
# rxr.open_rasterio('https://hls.gsfc.nasa.gov/data/v1.4/S30/2017/13/T/E/F/HLS.S30.T13TEF.2017002.v1.4.hdf')


if __name__ == '__main__':

    for arg in sys.argv[1:]:

        # Leer HDF
        ds = rxr.open_rasterio(arg)

        # Extraer min, mean y max para NDVI y EVI
        for var in ds.data_vars:
            if 'NDVI' in var or 'EVI' in var:

                # Extraer min, mean y max
                var_min = np.nanmin(ds.get(var).values)
                var_mean = np.nanmean(ds.get(var).values)
                var_max = np.nanmax(ds.get(var).values)

                # Imprimir valores extraídos
                print(f'File: {arg} ({var}) , min: {var_min}, mean: {var_mean}, max: {var_max}')

# ls data/*.hdf | xargs python hdf.py
