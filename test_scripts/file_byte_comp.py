#Kaveh Pezeshki
#Feb 7 2018
#Clay-Wolkin Research

import math

def compare_files(filename1, filename2, bitacc):
    '''filename1 and filename2 are filenames to compare, bitacc is the lsb (0, 1, 2) for which the files should match
    returns a tuple (boolean match, boolean avglsbdiff). avglsbdiff is 0 when the files are different lengths'''
    intlist1 = read_ints(filename1)
    intlist2 = read_ints(filename2)

    length = len(intlist1)
    countdiffs = 0
    numdiff = 2**bitacc
    sumdiff = 0
    diff = True
    avgdiff = 0

    if length != len(intlist2): return (False, 0)
    for pix in range(length):
        pixdiff = math.fabs(intlist1[pix] - intlist2[pix])
        if pixdiff > numdiff:
            diff = False
            sumdiff += pixdiff
            countdiffs += 1

    if countdiffs > 0:
        avgdiff = math.log(sumdiff/countdiffs, 2)

    return (diff, avgdiff)


def read_ints(filename): #reads a file as a list of 8-bit unsigned integers
    intlist = []
    with open(filename, 'rb') as f:
        byte = f.read(1)
        while byte:
            intlist.append(ord(byte))
            byte = f.read(1)
    return intlist

