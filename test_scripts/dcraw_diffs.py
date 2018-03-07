#Kaveh Pezeshki
#Feb 5 2018
#Clay-Wolkin Research


#This script will compile two different versions of DCraw with separated _dp and _v files. It will then execute DCraw with a given set of options on 5 input Canon .CR2 images, and examine any differences in the binary files.

#imports necessary for command-line interaction
import os
import subprocess
import file_byte_comp
from sys import exit


#-------------------USER SETTINGS----------------------

#file directory
directory = "/home/kaveh/tensorflow_loader"

#command line arguments for dcraw: ./<dcraw compiled name> <command line args> <image filename>
dcraw_args = " -r 1 1 1 1 -q 0"

#command line arguments for compiling dcraw
dcraw_comp = ["gcc -o "," -O4 "," -lm -DNODEPS"]

#image files to test on
image_filenames = ["IMG1.CR2", "IMG2.CR2", "IMG3.CR2"]

#input dcraw files to compile
#stored in two lists, where indices correspond to each of the two files to compile
dcraw_dp = ["dcraw_dp.c", "dcraw2_dp.c"]
dcraw_v  = ["dcraw2_v.c" , "dcraw2_v.c" ]

#names of output dcraw executables
dcraw_execs = ["dcraw1", "dcraw2"]

#checking image similarity within max_lsb_diff (as a power of 2)
#WARNING: this is really inefficient and takes ages
check_lsb = True
max_lsb_diff = 1


#-----------END OF USER SETTINGS----------------------
output_image_filenames = []
comparisons = [] #list of lists of lists, with row and col headings being processing methods for each image, and there being a list of this comparison table for each image

def shell_source(script):
    pipe = subprocess.Popen(". %s; env" % script, stdout=subprocess.PIPE, shell=True)
    output = pipe.communicate()[0]
    env = dict((line.split("=", 1) for line in output.splitlines()))
    os.environ.update(env)

#printing files in directory
print("-----STARTING TEST-----")
print("Files in working directory:")
for filein in os.listdir():
    print(filein + " ",end='')

#compiling DCraw versions
print("\n\n----COMPILING DCRAW VERSIONS----")
if len(dcraw_dp) != len(dcraw_v) or len(dcraw_dp) != len(dcraw_execs):
    sys.exit("cdraw dp and v file mismatch. Please check configuration")

i_execs = 0
for i in range(len(dcraw_dp)):
    #compiling
    comp_output = ""
    #shell_source(directory)
    comp_command = dcraw_comp[0] + dcraw_execs[i_execs] + dcraw_comp[1] + dcraw_dp[i] + " " + dcraw_v[i] + dcraw_comp[2]
    print("Compiling with: " + comp_command)
    comp_output = os.popen(comp_command).read()
    #print("GCC Compilation Output for " + dcraw_dp[i] + " and " + dcraw_v[i] + "\n" + comp_output)
    #testing compilation
    if dcraw_execs[i_execs] not in os.listdir(directory):
        print("----COMPILATION FAILED: EXEC DOES NOT EXIST----")
        dcraw_execs.remove(dcraw_execs[i_execs])
        i_execs -= 1
    else:
        print("----COMPILATION SUCCESSFUL----")
    i_execs += 1

print("\n----CONVERTING IMAGES----")
#testing DCraw versions on provided image sets
output_image_filenames = []
for exec_ver in dcraw_execs:
    for image in image_filenames:
        #image conversion
        print("Converting image " + image + " with DCraw version " + exec_ver)
        output_filename = image[0:-4] + "_" + exec_ver + ".ppm"
        output_image_filenames.append(output_filename)
        print("Output image filename: " + output_filename)
        output = os.popen("./"+exec_ver+dcraw_args+" "+image).read()
        #testing conversion
        if image[0:-4]+".ppm" not in os.listdir(directory):
            print("----IMAGE CONVERSION FAILED: .PPM NOT IN DIRECTORY----")
            output_image_filenames.remove(output_filename)
        else:
            print("----IMAGE CONVERSION SUCCESSFUL----")
            #image renaming
            os.popen("mv " + image[0:-4]+".ppm " + output_filename)

print("Converted images: " + str(output_image_filenames))

#comparing images between DCraw versions
print("\n----COMPARING IMAGES----")
for i in range(len(image_filenames)):
    #stores the filenames of the images that will be compared
    image_comp_names = []
    #stores the image comparison matrix
    image_comp_diffs = []

    #fetching image filenames
    for j in range(len(dcraw_execs)):
        image_comp_names.append(output_image_filenames[i+j*len(image_filenames)])
    #the first row of the matrix is a header with filenames
    image_comp_diffs.append(image_comp_names)

    #testing differences between files
    for img1 in image_comp_names:
        #differences for one row of the matrix: ex image 0 vs image 0, image 1, image 2, ...
        img1_diffs = []
        #cycling through images again
        for img2 in image_comp_names:
            print("Comparing images: " + img1 + " " + img2)
            #we don't need to run a test of an image against itself
            if img1 == img2 or image_comp_names.index(img2) < image_comp_names.index(img1):
                img1_diffs.append("X") #we use an 'X' when a test is not necessary
            else:
                if not check_lsb:
                    diff = os.popen("diff -q "+img1+" "+img2) #testing differences
                    diff_read = diff.read()
                    #print("Output: " + diff_read)
                    if "differ" in diff_read:
                        img1_diffs.append("F")  #we use 'F' if the images differ
                    else:
                        img1_diffs.append("T")  #we use 'T' if the image are the same
                else:
                    raw_diff = file_byte_comp.compare_files(img1, img2, max_lsb_diff)
                    if raw_diff[0] == True:
                        img1_diffs.append("T,"+str(raw_diff[1])[0:3])
                    else:
                        img1_diffs.append("F,"+str(raw_diff[1])[0:3])
        image_comp_diffs.append(img1_diffs) #once all the comparisons for a specific image version are complete we append the results array to the comparison matrix

    comparisons.append(image_comp_diffs) #once all the comparisons for a specific image are complete we append the comparison matrix the the complete comparison 3D matrix

#printing images
print("")
print("----IMAGE COMPARISON RESULTS----")
print("X corresponds to identical filenames or a symmetric test, T to identical images, F to different images")
print("X and Y column / row headings are identical. Y headings not shown.")
print("If checking similarity, output is of the form X/T/F , average lsb difference between all cases where a difference exists")

for image in comparisons:
    print("\nResults for image: " + image_filenames[comparisons.index(image)])
    #finding max string length
    maxprint = 0
    for name in image[0]:
        if len(name) > maxprint: maxprint = len(name)
    maxprint += 2 #provide spacing between cols
    for row in image:
        for item in row:
            print(item + " "*(maxprint-len(item)), end='')
        print("")
