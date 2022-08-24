# PSB Pipeline Downloads

Running the PSB Pipeline requires downloading a few public databases to sibling 
...../wherever/data/{pdb,swissmodel,modbase2020,alphafold,etc} sub-directories.

Use the short bash scripts provided here to ensure that your final filesystem layouts match pipeline code expectations.

The "top level" scripts download 3D structures and models, and genomic data files required for all pipeline versions.

The scripts in the SQL_population directory need only be run if you are setting up a SQL database for the pipeline.
Most pipeline users will run the pipeline from a container, and point it at the pre-loaded SQL database at
Vanderbilt.
