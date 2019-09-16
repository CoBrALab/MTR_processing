# MTR_processing
This is a pipeline for the processing of rodent Magnetization Transfer images. 

It is still under development!

Running the script:

mtr_processing_main.sh output_folder mt_image.mnc pd_image.mnc b1_60.mnc b1_120.mnc

where mt_image refers to the image acquired with the Magnetization Transfer prepulse, pd_image is the corresponding proton-density weighted image,
and b1_60 and b1_120 are the two B1 acquisitions acquired with the echo-planar-imaging double-angle-method.

What it does:

-preprocesses the images (fixes axis orientations, flips right/left ...)

-calculates the Magnetization Transfer Ratio (MTR) map

-calculates the B1 map

-registers the B1 map to the MTR map

-corrects for the B1 inhomogeneities in the MTR map using the linear calibration described in (Samson et al., 2006)

These calibration values are specific for the CIC animal scanner; protocols that use different sequence parameters may have to recalculate the calibration values.

-outputs a histogram of MTR values

