# BUSCO 4.1.4 'rU' mode fix

BUSCO 4.1.4's environment resolved to Python 3.13, which removed the
deprecated 'rU' file open mode entirely (removed in Python 3.11). This
causes BUSCO to crash partway through analysis with:

    ValueError: invalid mode: 'rU'

Fix: replace all instances of "rU" with "r" in BuscoTools.py:

    sed -i 's/"rU"/"r"/g' <path_to_busco_env>/lib/python3.13/site-packages/busco/BuscoTools.py

Four occurrences existed in this file (lines ~331, 339, 1417, 1665).
This patch is lost if the busco conda environment is recreated.
