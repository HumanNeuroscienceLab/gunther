# This script provides some simple tests to confirm that the generated fsf file really works

#---- version ----#

from feat_model_single import GenerateFSF
fsf = GenerateFSF('etc/template.fsf')
fsf.set_data(input_file='/mnt/nfs/psych/faceMemoryMRI/analysis/preprocessing/tb9226/Questions/run01.feat/filtered_func_data', 
  output_dir='/mnt/nfs/psych/faceMemoryMRI/analysis/fsl/Questions/tb9226/run01', 
  tr=1, 
  high_pass=200)
fsf.set_stats()
fsf.add_ev("bio", 
  "/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_bio", 
  "gamma", 
  filter=1, derivative=0
)
fsf.add_ev("phys", 
  "/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_phys", 
  "gamma", 
  filter=1, derivative=0
)
fsf.add_contrast("bio", [1,0]) # gsfs.add_afni_contrast("bio", "+bio")
fsf.add_contrast("phys", [0,1])
fsf.add_contrast("bio_gt_phys", [1,-1])
fsf.add_contrast("phys_gt_bio", [-1,1])
t = fsf.compile("etc/template_design.fsf")

# Gather template and reference text into a list
template_text = str(t)
with open("etc/sample_design.fsf") as file:
  ref_text = file.read()
template_text = [ line for line in template_text.split('\n') if line.strip() != '' ]
ref_text = [ line for line in ref_text.split('\n') if line.strip() != '' ]

# then do simplified diff
if len(template_text) != len(ref_text):
  print('lengths of template and reference differ')
nerrs = 0
for i in range(len(template_text)):
  if ref_text[i] != template_text[i]:
    nerrs += 1
    print('Error: line %i mismatch' % i)
    print('Ref: %s' % ref_text[i])
    print('Template: %s' % template_text[i])
if nerrs == 0:
  print('SUCCESS! ALL GOOD!')
  

#---- version ----#

from feat_model_single import GenerateFSF
fsf = GenerateFSF('etc/template.fsf')
fsf.set_data(input_file='/mnt/nfs/psych/faceMemoryMRI/analysis/preprocessing/tb9226/Questions/run01.feat/filtered_func_data', 
  output_dir='/mnt/nfs/psych/faceMemoryMRI/analysis/fsl/Questions/tb9226/run01', 
  tr=1, 
  high_pass=200)
fsf.set_stats()
fsf.add_ev("bio", 
  "/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_bio", 
  "gamma", 
  filter=1, derivative=0
)
fsf.add_ev("phys", 
  "/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_phys", 
  "gamma", 
  filter=1, derivative=0
)
fsf.add_contrast("bio", "+bio") # gsfs.add_afni_contrast("bio", "+bio")
fsf.add_contrast("phys", "+phys")
fsf.add_contrast("bio_gt_phys", "+bio -phys")
fsf.add_contrast("phys_gt_bio", "+phys -bio")
t = fsf.compile("etc/template_design.fsf")

# Gather template and reference text into a list
template_text = str(t)
with open("etc/sample_design.fsf") as file:
  ref_text = file.read()
template_text = [ line for line in template_text.split('\n') if line.strip() != '' ]
ref_text = [ line for line in ref_text.split('\n') if line.strip() != '' ]

# then do simplified diff
if len(template_text) != len(ref_text):
  print('lengths of template and reference differ')
nerrs = 0
for i in range(len(template_text)):
  if ref_text[i] != template_text[i]:
    nerrs += 1
    print('Error: line %i mismatch' % i)
    print('Ref: %s' % ref_text[i])
    print('Template: %s' % template_text[i])
if nerrs == 0:
  print('SUCCESS! ALL GOOD!')




from feat_model_single import GenerateFSF

# This script provides some simple tests to confirm that the generated fsf file really works

fsf = GenerateFSF('etc/template.fsf')
fsf.set_data(input_file='/mnt/nfs/psych/faceMemoryMRI/analysis/preprocessing/tb9226/Questions/run01.feat/filtered_func_data', 
  output_dir='/mnt/nfs/psych/faceMemoryMRI/analysis/fsl/Questions/tb9226/run01', 
  tr=1, 
  high_pass=200)
fsf.set_stats()
fsf.add_ev("bio", 
  "/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_bio", 
  "gamma", 
  filter=1, derivative=0
)
fsf.add_ev("phys", 
  "/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_phys", 
  "gamma", 
  filter=1, derivative=0
)
fsf.add_contrast("bio", [1,0]) # gsfs.add_afni_contrast("bio", "+bio")
fsf.add_contrast("phys", [0,1])
fsf.add_contrast("bio_gt_phys", [1,-1])
fsf.add_contrast("phys_gt_bio", [-1,1])
t = fsf.compile("etc/template_design.fsf")

# Gather template and reference text into a list
template_text = str(t)
with open("etc/sample_design.fsf") as file:
  ref_text = file.read()
template_text = [ line for line in template_text.split('\n') if line.strip() != '' ]
ref_text = [ line for line in ref_text.split('\n') if line.strip() != '' ]

# then do simplified diff
if len(template_text) != len(ref_text):
  print('lengths of template and reference differ')
nerrs = 0
for i in range(len(template_text)):
  if ref_text[i] != template_text[i]:
    nerrs += 1
    print('Error: line %i mismatch' % i)
    print('Ref: %s' % ref_text[i])
    print('Template: %s' % template_text[i])
if nerrs == 0:
  print('SUCCESS! ALL GOOD!')







#----------- COMMAND-LINE -----------#

cmd = """
/Users/czarrar/anaconda/bin/python feat_model_single.py \
  --no-run \
  -i '/mnt/nfs/psych/faceMemoryMRI/analysis/preprocessing/tb9226/Questions/run01.feat/filtered_func_data' \
  -o '/mnt/nfs/psych/faceMemoryMRI/analysis/fsl/Questions/tb9226/run01' \
  --outfile 'etc/template_design.fsf' \
  --tr 1 --high-pass 200 \
  --prewhiten \
  --stim bio '/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_bio' "model=gamma, filter=true, derivative=false" \
  --stim phys '/mnt/nfs/psych/faceMemoryMRI/command/timing/faceMemory01_tb9226_Questions_run01_phys' "model=gamma, filter=true, derivative=false" \
  --glt bio "SYM: +bio" \
  --glt phys "SYM: +phys" \
  --glt bio_gt_phys "SYM: +bio -phys" \
  --glt phys_gt_bio "SYM: +phys -bio"
"""

import os
os.system(cmd)

# Gather template and reference text into a list
with open("etc/template_design.fsf") as file:
  template_text = file.read()
with open("etc/sample_design.fsf") as file:
  ref_text = file.read()
template_text = [ line for line in template_text.split('\n') if line.strip() != '' ]
ref_text = [ line for line in ref_text.split('\n') if line.strip() != '' ]

# then do simplified diff
if len(template_text) != len(ref_text):
  print('lengths of template and reference differ')
nerrs = 0
for i in range(len(template_text)):
  if ref_text[i] != template_text[i]:
    nerrs += 1
    print('Error: line %i mismatch' % i)
    print('Ref: %s' % ref_text[i])
    print('Template: %s' % template_text[i])
if nerrs == 0:
  print('SUCCESS! ALL GOOD!')
