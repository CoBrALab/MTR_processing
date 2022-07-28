# **What is Magnetization Transfer Imaging (MTI)?**

Magnetization Transfer (MT) is an MRI technique that allows for an estimation of myelin content. 
The Magnetization Transfer Ratio (MTR) in particular is a semi-quantitative measure of myelin concentration, meaning that it is an estimate of relative myelin content. 

Although there exist other MRI techniques for imaging myelin, MTR has previously shown a reasonable tradeoff between specificity to myelin and a straightforward implementation, requiring only a simple calculation of the ratio between two images, one with a MT saturation pulse and one without. 

# **Performing MTI on mice at the CIC**

## MRI acquisitions:
* Proton-density weighted acquisition (~10 min)
* Acquisition preceded by MT-pulse (~10 min)
* B1 field mapping with the double angle method (DAM): 2 EPI acquisitions, one with a 60 degree flip angle (~2 min) and one with a 120 degree flip angle (~2 min)

The total acquisition time is ~30 minutes. Mice can be anesthetized according to standard protocol. Acquisitions can be performed using the room-temperature coil or CryoProbe - if using the CryoProbe, there will be signal drop-off in the ventral regions of the brain so the two EPI acquisitions are absolutely necessary in order to partially correct for this. If the room-temperature coil is used, there are minor variations in field strength (10% change in MTR) so the EPI acquisitions are still recommended.

The necessary sequences for the above acquisitions are all developed and present on the CIC animal scanner (PV5). To perform the B1 field mapping using a 120 degree flip angle, simply use the same sequence as for the 60 degrees and adjust the flip angle by manually setting the attenuation, then GOP.

Important: Make sure that the 'RECO_map_mode' parameter is set to 'ABSOLUTE MAPPING' for all acquisitions. Also, make sure that the receiver gain is the same for the PDw and MTw acquisitions - first acquire the PDw, then either use GOP for the MTw or manually set the receiver gain to be the same as the one that was automatically determined for the PDw.

# **Image Processing**

The mtr_processing_main.sh script performs all necessary preprocessing and mtr-related processing on raw minc inputs. 

## Overview of script function:
* pre-processes and denoises the images, produces masks
* creates the MTR map by taking the voxel-wise ratio of the proton density-weighted acquisition and the MT-pulse acquisition
* Creates a B1 field map using the two EPI acquisitions (map of the pulse strength)
* Corrects the MTR map for the inhomogeneities in signal strength using the B1 field map to produce a final MTR map

* MTw stands for MT-pulse acquisition, PDw stands for proton-density acquisition, B1 (60) is 60 degree EPI, and B1 (120) stands for the 120 degree EPI acquisition. The black arrows indicate the images that were used as input for the creation of downstream images. The grat arrows indicate the files that were used that were used for registration.
![pipeline_worflow](https://user-images.githubusercontent.com/47565996/122585037-091c0580-d029-11eb-924d-c31f4008d606.png)

## To run the script from a CIC computer:

1. Create the necessary environment using the provided .yml file. This will provide all the necessary python packages.

`conda env create -f mtr_processing_env.yml`

2. Convert your raw MRI scans to nifti using brkraw (see wiki page title bruker2nifti conversion).

3. Run the script (the environment is activated within the script).

`mtr_processing_main.sh output_folder sub-001_acq-cryo_MTw.nii.gz sub-001_acq-cryo_PDw.nii.gz sub-001_acq-cryo_flip-60_B1dam.nii.gz sub-001_acq-cryo_flip-120_B1dam.nii.gz `

* the script assumes that all 4 acquisitions were taken consecutively and with no changes in mouse positioning
* for the output files to have proper names, the input mincs must follow the naming convention sub-SUBNUM_acq-coil_type.nii.gz, SUBNUM is replaced by the subject ID, coil is replaced either by ‘cryo’ or ‘nrm’ to indicate either cryocoil or room-temperature coil, and type is MTw, PDw or B1dam. If the type if B1dam, you also need the flip argument, either flip-60 or flip-120 to indicate the flip angle used. This naming convention follows the BIDS format.

4. a) If you want to run the script on multiple subjects at once - use the qbatch module. First, create a joblist.sh file where each line in the file contains a command for a single subject, as in step 2. 

4.b) Load the qbatch module. Also load minc-toolkit, minc-toolkit-extras and ANTs modules, then activate the environment. Normally these steps are done within the script itself, but they won't work properly when you're using qbatch. 

```
module load qbatch
module load minc-toolkit
module load minc-toolkit-extras
module load ANTs
source activate mtr_processing_env
```
4. c) Now submit your joblist to qbatch. It will run all your commands in parallel. It is recommended to try on a single subject first (without qbatch) before running all of them.

`qbatch joblist.sh`

# **Output folders**
![tree](https://user-images.githubusercontent.com/47565996/151047082-8b76379e-2c36-40d0-ad4d-4b339c181838.png)

* ‘raw_minc’ folder: raw minc files for all acquisitions (mt, pd, b1_60 and b1_120)
* ‘n4_bias_corrected’ folder: N4-bias field corrected outputs for all inputs. These outputs are used for subsequent registrations but not for analysis/ mtr map creation.
* ‘transforms_subject_to_DSURQE’ folder: contains the nonlinear and affine .xfm files to go from subject space to the DSURQE atlas space.
* ‘masks’ folder: contains one whole-brain mask for each coil_subjectid, as well as a mask with the CSF removed. Created from the preprocessed pd image. 
* ‘subject-specific tissue masks‘ folder: contains a gray matter (gm), white matter (wm) and corpus callosum (cc) registered to each subject.
* ‘b1_maps’ folder: contains one b1 map per coil_subjectid. 
The ‘registered_b1_to_mtr’ subfolder contains affine and non-linear transforms from the b1 map to the mtr map, as well as the final b1 map that is registered to the mtr map. This registration will account for the difference in resolution between the b1 and mtr maps. 
The ‘registered_and_normalized_b1’ subfolder contains the b1 maps from the ‘registered_b1_to_mtr’ subfolder, except they are normalized by dividing by 60 degrees.
* 'denoised_nonlocal_means' folder: contains the raw MTw and PDw acquisitions, except denoised to remove Rician noise.
* ‘mtr_maps’ folder: contains one mtr map per coil_subjectid.
The 'mtr_maps_raw' subfolder contains MTR maps made directly from the raw minc images.
The 'mtr_maps_denoised' subfolder contains MTR maps constructed from the denoised_nonlocal_means MTw and PDw images.
The ‘mtr_maps_denoised_corrected’ subfolder contains the mtr maps from the ‘mtr_maps_denoised’ folder, except they are corrected according to the b1 field using a linear calibration that depends on the coil type. 


# **Preview of the outputs**

Raw MT Acquisition &nbsp; &nbsp; &nbsp;  Preprocessed &nbsp; &nbsp; &nbsp; Denoised  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;   Mask  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;  MTR map &nbsp; &nbsp; &nbsp; &nbsp; Corrected MTR &nbsp; &nbsp; &nbsp; B1 map 

![documentation_outputs](https://user-images.githubusercontent.com/47565996/72276873-e2b99580-35fe-11ea-9db1-813f34c64119.png)

(cryocoil)

# **Interpreting the MTR map**

Voxels with a higher MTR value have a higher concentration of myelin than voxels with a lower MTR value. Typical values for the MTR in the corpus callosum region are around 45-55%. However, these values will be highly dependent on the pulse sequence that is used.

The reason why more myelin means a higher MTR is because when the MT-pulse is applied, protons in the myelin will become saturated and will have a smaller signal during a subsequent pulse; thus the MT-pulse suppresses the signal in myelinated regions. Since the MTR is calculated by subtracting the MT-pulse acquisition from the proton-density weighted acquisition, myelinated regions will have a higher MTR value.

# **References**
* Two-level DBM - https://github.com/CoBrALab/twolevel_ants_dbm
* ANTs - https://github.com/ANTsX/ANTs
* RABIES - https://github.com/CoBrALab/RABIES
* MINC - https://github.com/CoBrALab/minc-toolkit-extras
***
