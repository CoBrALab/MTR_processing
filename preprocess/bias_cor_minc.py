#this script is courtesy of Gabriel Devenyi
import os
import sys

file=os.path.abspath(sys.argv[1])
anat=os.path.abspath(sys.argv[2])
anat_mask=os.path.abspath(sys.argv[3])
reg_script_path=os.path.abspath(sys.argv[4])
biascor_EPI=sys.argv[5]

import numpy as np
import SimpleITK as sitk

rabies_data_type=sitk.sitkFloat32

import pathlib  # Better path manipulation
filename_split = pathlib.Path(
    file).name.rsplit(".mnc")

cwd = os.getcwd()
#warped_image = '%s/%s_output_warped_image.mnc' % (
#    cwd, filename_split[0])
resampled = '%s/%s_resampled.mnc' % (
    cwd, filename_split[0])
resampled_mask = '%s/%s_resampled_mask.mnc' % (
    cwd, filename_split[0])
#biascor_EPI = '%s/%s_bias_cor.mnc' % (cwd, filename_split[0],)


# resample to isotropic resolution based on lowest dimension
input_ref_EPI_img = sitk.ReadImage(
    file, rabies_data_type)

# the -b will be rounded up to the nearest multiple of 10 of the image largest dimension
largest_dim = (np.array(input_ref_EPI_img.GetSize())*np.array(input_ref_EPI_img.GetSpacing())).max()
b_value = int(np.ceil(largest_dim/10)*10)

bias_cor_input = file

def otsu_bias_cor(target, otsu_ref, out_name, b_value, mask=None, n_iter=100):
    import SimpleITK as sitk
    import os
    null_mask=os.path.abspath('null_mask.mnc')
    otsu_weight=os.path.abspath('otsu_weight.mnc')
    command = 'ImageMath 3 %s ThresholdAtMean %s 0' % (null_mask,otsu_ref)
    rc = os.system(command)
    command = 'ThresholdImage 3 %s %s Otsu 4' % (otsu_ref, otsu_weight)
    rc = os.system(command)

    otsu_img = sitk.ReadImage(
        otsu_weight, sitk.sitkUInt8)
    otsu_array = sitk.GetArrayFromImage(otsu_img)

    if mask is not None:
        resampled_mask_img = sitk.ReadImage(
            mask, sitk.sitkUInt8)
        resampled_mask_array = sitk.GetArrayFromImage(resampled_mask_img)

        otsu_array = otsu_array*resampled_mask_array

    combined_mask=(otsu_array==1.0)+(otsu_array==2.0)
    mask_img=sitk.GetImageFromArray(combined_mask.astype('uint8'), isVector=False)
    mask_img.CopyInformation(otsu_img)
    sitk.WriteImage(mask_img, os.path.abspath('mask12.mnc'))

    combined_mask=(otsu_array==3.0)+(otsu_array==4.0)
    mask_img=sitk.GetImageFromArray(combined_mask.astype('uint8'), isVector=False)
    mask_img.CopyInformation(otsu_img)
    sitk.WriteImage(mask_img, os.path.abspath('mask34.mnc'))

    combined_mask=(otsu_array==1.0)+(otsu_array==2.0)+(otsu_array==3.0)
    mask_img=sitk.GetImageFromArray(combined_mask.astype('uint8'), isVector=False)
    mask_img.CopyInformation(otsu_img)
    sitk.WriteImage(mask_img, os.path.abspath('mask123.mnc'))

    combined_mask=(otsu_array==2.0)+(otsu_array==3.0)+(otsu_array==4.0)
    mask_img=sitk.GetImageFromArray(combined_mask.astype('uint8'), isVector=False)
    mask_img.CopyInformation(otsu_img)
    sitk.WriteImage(mask_img, os.path.abspath('mask234.mnc'))

    combined_mask=(otsu_array==1.0)+(otsu_array==2.0)+(otsu_array==3.0)+(otsu_array==4.0)
    mask_img=sitk.GetImageFromArray(combined_mask.astype('uint8'), isVector=False)
    mask_img.CopyInformation(otsu_img)
    sitk.WriteImage(mask_img, os.path.abspath('mask1234.mnc'))

    command = 'N4BiasFieldCorrection -d 3 -i %s -b %s -s 1 -c [%sx%sx%s,1e-4] -w %s -x %s -o %s -v' % (target, str(b_value), str(n_iter),str(n_iter),str(n_iter),os.path.abspath('mask12.mnc'),null_mask,os.path.abspath('corrected1.mnc'),)
    rc = os.system(command)

    command = 'N4BiasFieldCorrection -d 3 -i %s -b %s -s 1 -c [%sx%sx%s,1e-4] -w %s -x %s -o %s -v' % (os.path.abspath('corrected1.mnc'), str(b_value), str(n_iter),str(n_iter),str(n_iter),os.path.abspath('mask34.mnc'),null_mask,os.path.abspath('corrected2.mnc'),)
    rc = os.system(command)

    command = 'N4BiasFieldCorrection -d 3 -i %s -b %s -s 1 -c [%sx%sx%s,1e-4] -w %s -x %s -o %s -v' % (os.path.abspath('corrected2.mnc'), str(b_value), str(n_iter),str(n_iter),str(n_iter),os.path.abspath('mask123.mnc'),null_mask,os.path.abspath('corrected3.mnc'),)
    rc = os.system(command)

    command = 'N4BiasFieldCorrection -d 3 -i %s -b %s -s 1 -c [%sx%sx%s,1e-4] -w %s -x %s -o %s -v' % (os.path.abspath('corrected3.mnc'), str(b_value), str(n_iter),str(n_iter),str(n_iter),os.path.abspath('mask234.mnc'),null_mask,os.path.abspath('corrected4.mnc'),)
    rc = os.system(command)

    command = 'N4BiasFieldCorrection -d 3 -i %s -b %s -s 1 -c [%sx%sx%s,1e-4] -w %s -x %s -o %s -v' % (os.path.abspath('corrected4.mnc'), str(b_value), str(n_iter),str(n_iter),str(n_iter),os.path.abspath('mask1234.mnc'),null_mask,out_name,)
    rc = os.system(command)


otsu_bias_cor(target=bias_cor_input, otsu_ref=bias_cor_input, out_name=cwd+'/corrected_iter1.mnc', b_value=b_value, n_iter=200)
otsu_bias_cor(target=bias_cor_input, otsu_ref=cwd+'/corrected_iter1.mnc', out_name=cwd+'/corrected_iter2.mnc', b_value=b_value, n_iter=200)

command = 'bash %s %s %s %s %s' % (reg_script_path, cwd+'/corrected_iter2.mnc', anat, anat_mask, cwd+'/'+filename_split[0],)
rc = os.system(command)

command = 'antsApplyTransforms -d 3 -i %s -t [%s_output_0_GenericAffine.xfm,1] -r %s -o %s -n GenericLabel' % (anat_mask,cwd+'/'+filename_split[0], cwd+'/corrected_iter2.mnc',resampled_mask)
rc = os.system(command)

otsu_bias_cor(target=bias_cor_input, otsu_ref=cwd+'/corrected_iter2.mnc', out_name=cwd+'/final_otsu.mnc', b_value=b_value, mask=resampled_mask, n_iter=200)


# resample to anatomical image resolution
dim = sitk.ReadImage(anat, rabies_data_type).GetSpacing()
low_dim = np.asarray(dim).min()
sitk.WriteImage(sitk.ReadImage(cwd+'/final_otsu.mnc'), biascor_EPI)

sitk.WriteImage(sitk.ReadImage(biascor_EPI, rabies_data_type), biascor_EPI)
#sitk.WriteImage(sitk.ReadImage(warped_image, rabies_data_type), warped_image)
sitk.WriteImage(sitk.ReadImage(resampled_mask, rabies_data_type), resampled_mask)
