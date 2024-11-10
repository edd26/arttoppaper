# ArtTopology


The code provided here reproduces the figures from the paper:
* Dmitruk, E., Bajno, B., Dreszer, J., Bałaj, B., Ratajczak, E., Hajnowski, M., Janik, R. A., Kuś, M., Kadir, S. N., & Rogala, J.: [Art’s Hidden Topology: A window into human perception](https://doi.org/10.1101/2024.10.16.618741) (p. 2024.10.16.618741). bioRxiv.

## Introduction
The code was written by Emil Dmitruk*, and the underlying ideas are the result of joint work with [Shabnam Kadir(*)](https://github.com/shabnamkadir), Jacek Rogala and Marek Kuś.

(*)[UHBiocomputation Group](http://biocomputation.herts.ac.uk/)

This code base is using the Julia Language and [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/)
to make a reproducible scientific project named
> ArtTopology

## Installation and requirements
0. Download this code base. Notice that raw data are typically not included in the
   git-history and may need to be downloaded independently.
1. Open the terminal and navigate to the downloaded repository
2. Run Julia in the terminal and run the following:
   ```
   julia> ]
   (julia-version) pkg> add DrWatson # install globally, for using `quickactivate`
   (julia-version) pkg> activate .
   (ArtTopology) pkg> instantiate
   ```
Please note that the first line uses a closing square bracket to activate Julia's package manager.

The last step will install all the packages necessary to run most of the scripts.
However, 2 additional dependencies are required to run the code (please see below).

3a. Install dependencies for DIPHA, which are CMake and MPI. On the Ubuntu system, this could be done
with:
```sh
sudo apt install cmake
sudo apt install openmpi-bin openmpi-common libopenmpi-dev
```
Please see the DIPHA submodule for more explanation.

3b. Compile DIPHA with the following commands (DIPHA is a dependency included as a submodule):
   ```sh
   git submodule update --init --recursive
   cd dipha
   cmake ./
   make
   ```
   Dipha is then used from within Julia's script to obtain cubical complexes of images.
   
4. Python in version 3 with Numpy version 2.0 and above

Note: The DrWatson package ensures that all the file management should work out of the box,
using repository structure for navigation. 

## Preprocessing

All images must be converted into grayscale before being used in the repository.
This can be done with the script `scripts/0a_convert_samples_to_bw.jl`. In order
to utilise the automation of the script for a dataset, it is advised to do the following:
1. Add a dataset to folder `data/exp_raw` under some name, e.b. `dataset1`
2. Add a tuple with the dataset name to the configuration file `scripts/config.jl` under "Datasets
paths configuration" and add it to the `raw_paths` variable (please see that file for 2 samples).
3. Run the conversion script as
```julia
julia scripts/0a_convert_samples_to_bw.jl --data_set dataset1 --data_config BW
```
to run the conversion to grayscale (optionally, `BW` could be changed to `WB` to
create inversed, greyscale of the image, which is required for some scripts).
   - this loads files from `data/exp_raw/dataset1`
   - results are saved in `data/exp_pro/img_initial_preprocessing/dataset1`

#### Preprocessing piepline
0. Preprocess the data if needed (see above).
1. Convert images to Dipha format with script `scripts/1a_convert_images_for_dipha.jl`
   - this loads files from `data/exp_pro/img_initial_preprocessing`
   - results are saved in `data/exp_pro/img_dipha_input`
2. Run DIPHA analysis with script `scripts/1b_dipha_analysis.jl`
   - this loads files `data/exp_pro/img_dipha_input`
   - results are saved in `data/exp_pro/dipha_raw_results`
3. Export birth-death diagrams from raw files with: `scripts/1c_export_birth_death_data.jl`
   - this loads files `data/exp_pro/dipha_raw_results`
   - results are saved in `data/exp_pro/dipha_bd_data`

### Obtaining figures from the paper

Figures from the paper can be obtained by executing the scripts, e.g. the following code:
```julia
julia scripts/17g_makie_plot_cycles_with_persistence.jl --data_set fake --data_config BW
```
will provide figures presented in Figure 5. Option `dataset` determines which images will be used from the paper. Option `data_config` determines which filtration will be used (please see `src/ArgsParsing.jl` for all details about the arguments for the scripts). Please use the list below to obtain desired figures.

List of figures that were produced with scripts
- fig 5. Produced with 17g, 17id, 17ie2
- fig 10. Produced with 2f3b2
- fig 11. Produced with 2gd2
- fig 12. Produced with 2m4
- fig 13. Produced with 17g
- fig 14. Produced with 17g and 17h
- fig 15. Produced with 17ig3lb2
- fig 10. Produced with 2f3b2
- fig 11. Produced with 2gd2
- fig 12. Produced with 2m4
- fig 13. Produced with 17g
- fig 14. Produced with 17g and 17h
- fig 15. Produced with 17ig3lb2
- fig 10. Produced with 2f3b2
- fig 11. Produced with 2gd2
- fig 12. Produced with 2m4
- fig 13. Produced with 17g
- fig 14. Produced with 17g and 17h
- fig 15. Produced with 17ig3lb2
- fig 10. Produced with 2f3b2
- fig 11. Produced with 2gd2
- fig 12. Produced with 2m4
- fig 13. Produced with 17g
- fig 14. Produced with 17g and 17h
- fig 15. Produced with 17ig3lb2
- fig 16. Produced with 17jg3k2
- fig 17. Produced with 14c

- Supplementary fig 3. Produced with 2f3b2
- Supplementary fig 4. Produced with 2f3b2
- Supplementary fig 5. Produced with 2m4
- Supplementary fig 7. Produced with 2gb2a
- Supplementary fig 8. Produced with 12c2
- Supplementary fig 9. Produced with 17g
- Supplementary fig 10. Produced with 17g
- Supplementary fig 11. Produced with 17g
- Supplementary fig 12. Produced with 17g
- Supplementary fig 13. Produced with 17h4
- Supplementary fig 14. Produced with 17ig2g and 17jg2g 
- Supplementary fig 15. Produced with 17ig2g and 17jg2g 
- Supplementary fig 16. Produced with 17ig2g and 17jg2g 
- Supplementary fig 17. Produced with 17ig3da 
- Supplementary fig 18. Produced with 17ig3da 
- Supplementary fig 18. Produced with 17ig3da 

### Section 17

To run code from the section 17, Python has to be installed, together with a
Numpy library- an error will be thrown if Numpy is not available. If this happens,
please follow the instructions provided in the message.
