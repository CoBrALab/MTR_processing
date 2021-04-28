# **What is Magnetization Transfer Imaging (MTI)?**

Magnetization Transfer (MT) is an MRI technique that allows for an estimation of myelin content. 
The Magnetization Transfer Ratio (MTR) in particular is a semi-quantitative measure of myelin concentration, meaning that it indicates the relative myelin content but doesn’t have a direct biological interpretation. 

Although there exist other MRI techniques for imaging myelin, MTR has previously shown a reasonable tradeoff between specificity to myelin and a straightforward implementation, requiring only a simple calculation of the ratio between two images, one with a MT saturation pulse and one without. 

# **Performing MTI on mice at the CIC**

## MRI acquisitions:
* Proton-density weighted acquisition (~10 min)
* Acquisition preceded by MT-pulse (~10 min)
* B1 field mapping with the double angle method (DAM): 2 EPI acquisitions, one with a 60 degree flip angle (~2 min) and one with a 120 degree flip angle (~2 min)

The total acquisition time is ~30 minutes. Mice can be anesthetized according to standard protocol. Acquisitions can be performed using the room-temperature coil or CryoProbe - if using the CryoProbe, there will be signal drop-off in the ventral regions of the brain so the two EPI acquisitions are absolutely necessary in order to partially correct for this. If the room-temperature coil is used, there are minor variations in field strength (10% change in MTR) so the EPI acquisitions are still recommended.

The necessary sequences for the above acquisitions are all developed and present on the CIC animal scanner (PV5). To perform the B1 field mapping using a 120 degree flip angle, simply use the same sequence as for the 60 degrees and adjust the flip angle by manually setting the attenuation.

# **Image Processing**

The mtr_processing_main.sh script performs all necessary preprocessing and mtr-related processing on raw minc inputs. 

## Path to script on CIC:
_/data/chamal/projects/mila/2019_Magnetization_Transfer/scripts/mtr_processing_main.sh_

## Overview of script function:

* pre-processes and denoises the images, produces masks
* creates the MTR map by taking the voxel-wise ratio of the proton density-weighted acquisition and the MT-pulse acquisition
* Creates a B1 field map using the two EPI acquisitions (map of the pulse strength)
* Corrects the MTR map for the inhomogeneities in signal strength using the B1 field map to produce a final MTR map

* _mt stands for MT-pulse acquisition, pd stands for proton-density acquisition, b1_60 is 60 degree EPI, and b1_120 stands for the 120 degree EPI acquisition.
![MTR_pipeline_workflow](https://user-images.githubusercontent.com/47565996/88414447-3decf180-cdb3-11ea-90aa-c6bd84fa32a6.png)

## To run the script from a CIC computer:

1. Create the necessary environment using the provided .yml file. This will provide all the necessary python packages.

*conda env create -f mtr_processing_env.yml*

2. Run the script (the environment is activated within the script).

_mtr_processing_main.sh output_folder coil_subjectid_mt_timepoint.mnc coil_subjectid_pd_timepoint.mnc coil_subjectid_b1_60_timepoint.mnc coil_subjectid_b1_120_timepoint.mnc_

* the output_folder name should not have a ‘/’ at the end. 
* the script assumes that all 4 acquisitions were taken consecutively and with no changes in mouse positioning
* for the output files to have proper names, the input mincs must follow the naming convention coil_subjectid where coil is replaced either by ‘cry’ or ‘nrm’ to indicate either cryocoil or room-temperature coil, and subjectid is a 3-digit mouse ID. Finally, additional numbers at the end can be added to indicate timepoint. For example: cry_001_mt_1.mnc

# **Output folders**
![image](https://user-images.githubusercontent.com/47565996/116478032-7d1d0700-a84b-11eb-90f5-6c6689ee34f6.png)

* ‘preprocessed’ folder: orientation-corrected outputs for all inputs (mt, pd, b1_60 and b1_120)
* ‘denoised’ folder: N4-bias field corrected outputs for all inputs. These outputs are used for subsequent registrations but not for analysis/ mtr map creation.
* ‘transforms_subject_to_DSURQE’ folder: contains the nonlinear and affine .xfm files to go from subject space to the DSURQE atlas space.
* ‘masks’ folder: contains one whole-brain mask for each coil_subjectid. Created from the preprocessed pd image. 
* ‘subject-specific tissue masks‘ folder: contains a gray matter (gm), white matter (wm) and corpus callosum (cc) registered to each subject.
* ‘B1_maps’ folder: contains one b1 map per coil_subjectid. 
The ‘registered_b1_to_mtr’ subfolder contains affine and non-linear transforms from the b1 map to the mtr map, as well as the final b1 map that is registered to the mtr map. This registration will account for the difference in resolution between the b1 and mtr maps. 
The ‘normalized_and_registered_b1’ subfolder contains the b1 maps from the ‘registered_b1_to_mtr’ subfolder, except they are normalized by dividing by 60 degrees.
* ‘mtr_maps’ folder: contains one mtr maps per coil_subjectid.
The ‘corrected_mtr_maps’ subfolder contains the mtr maps from the ‘mtr_maps’ folder, except they are corrected according to the b1 field using a linear calibration that depends on the coil type. 


# **Preview of the outputs**

Raw MT Acquisition &nbsp; &nbsp; &nbsp;  Preprocessed &nbsp; &nbsp; &nbsp; Denoised  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;   Mask  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;  MTR map &nbsp; &nbsp; &nbsp; &nbsp; Corrected MTR &nbsp; &nbsp; &nbsp; B1 map 

![documentation_outputs](https://user-images.githubusercontent.com/47565996/72276873-e2b99580-35fe-11ea-9db1-813f34c64119.png)

(cryocoil)

# **Interpreting the MTR map**

Voxels with a higher MTR value have a higher concentration of myelin than voxels with a lower MTR value. Typical values for the MTR in the corpus callosum region are around 45-55%. 

The reason why more myelin means a higher MTR is because when the MT-pulse is applied, protons in the myelin will become saturated and will have a smaller signal during a subsequent pulse; thus the MT-pulse suppresses the signal in myelinated regions. Since the MTR is calculated by subtracting the MT-pulse acquisition from the proton-density weighted acquisition, myelinated regions will have a higher MTR value.


***
