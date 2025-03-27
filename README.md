# PSB Pipeline Downloads

Running the VUStruct Pipeline (or using the supporting pdbmap library)
requires downloading a few public databases to sibling directories:

...../wherever/data/{pdb,swissmodel,modbase2020,alphafold,etc} sub-directories.

Use the short bash scripts provided here to ensure that your final filesystem layouts match pipeline code expectations.

The "top level" scripts download 3D structures and models, and genomic data files required for all pipeline versions.

The scripts in the SQL_population directory need only be run if you are setting up a local SQL database for 
your own pipeline deploment.  Most pipeline users will simply run variants through the meilerlab.org/VUStruct 
launch form.
