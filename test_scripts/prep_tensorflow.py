#Kaveh Pezeshki
#March 6 2018
#Clay-Wolkin Research

#This script will, when executed in a directory containing multiple DCraw executable files and a .CR2 image set, create a new directory with converted .PNG images for every DCraw executable in new directories at the same level as the original

#imports necessary for command-line interaction
import os
import subprocess
from sys import exit

#-------------USER SETTINGS-------------

#top-level directory
directory = "/home/kaveh/cw/images/images"

#image conversion directory
directory_conv = "/home/kaveh/cw/images/images/raw"

#dcraw executables
dcraw_execs = ["dcraw_dp_fixed4", "dcraw_dp_fixed6", "dcraw_dp_fixed8"]

#dcraw conversion command
dcraw_conv = "-r 1 1 1 1 -q 0"

#ppm -> png conversion command
conv_cmd = "mogrify -format png *.ppm"

#------END OF USER SETTINGS------------

directories = []

print("\n-----STARTING CONVERSION-----")

print("\n-----CREATING DIRECTORIES-----")
dir_prefix = directory_conv+"_"
for executable in dcraw_execs:
    dir_to_create = dir_prefix + executable
    print("creating: " + dir_to_create)
    os.popen("mkdir " + dir_to_create)
    #print("mkdir " + dir_to_create)
    directories.append(dir_to_create)

print("\n-----CONVERTING IMAGES------")
for executable in dcraw_execs:
    print("\nconverting to ppm with: " + executable)
    output = os.popen("cd "+ directory_conv + "; "+ " for filename in *.CR2 ; do ./" + executable + " " + dcraw_conv + " \"$filename\" ; done").read()
    print("cd "+ directory_conv  + "; "+ " for filename in *.CR2 ; do ./" + executable + " " + dcraw_conv + " \"$filename\" ; done")
    print(output)
    #print("cd "+ directory_conv + "; " "for filename in *.CR2 ; do sh " + executable + " " + dcraw_conv + " \"$filename\" ; done")
    print("converting to png")
    os.popen("cd " + directory_conv + "; "  + conv_cmd)
    #print("cd " + directory_conv + "; "  + conv_cmd)
    print("moving images to directory")
    dir_to_move = dir_prefix + executable
    os.popen("mv " + directory_conv + "/*.png " + dir_to_move)
    #print("mv " + directory_conv + "/*png " + dir_to_move)
    print("cleaning up")
    #print("rm " + directory_conv + " *.ppm")
    os.popen("rm " + directory_conv + "/*.ppm")
