
import sys

import numpy as np
import xarray as xr

from datetime import datetime, timedelta


if __name__ == '__main__':

    for arg in sys.argv[1:]:

        ds = xr.open_dataset(arg)

        ref_date = ds.attrs.get('Reference Date')

        for var in [str(x) for x in ds.data_vars]:

            var_values = ds.get(var).copy(deep=True)
            var_values = xr.where(var_values > 10, np.nan, var_values)

            for time, group in var_values.groupby('time'):
                fecha = datetime.strptime(ref_date, "%Y-%m-%d").date() + timedelta(days=int(time))
                if not np.isnan(group.values).all():
                    print(f'{arg} - {var} - {fecha} - min: {np.nanmin(group.values)} - max: {np.nanmax(group.values)}')

# ls *.nc | xargs python netcdf.py
