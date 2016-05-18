#!/usr/bin/env python

from Cheetah.Template import Template
import os
import argparse
import re
import tempfile

# This script will compile an FSL Feat Design File for the first level

class GenerateFSF(object):
  """
  Generates the FSF file for FSL's Feat analysis.
  """
  def __init__(self, template_file):
    self.template_file = template_file
    self.data_vars = {}
    self.stats_vars = {}
    self.evs = []
    self.ev_names = []
    self.contrasts = []
    self.template = None
    return
  
  def set_data(self, input_file, output_dir, tr, high_pass=None, apply_filter=False):
    """
      Save the main variables to substitute in the FSF file
    
      Paramaters
      ----------
      input_file : string
        input functional file
      output_dir : string
        output feat directory
      tr : float
        repetition time
      high_pass : float (default: None)
        high-pass filter (used for filtering EVs)
    
      Returns
      -------
    
      Examples
      --------
      >>> tmp = GenerateFSF('template.fsf')
      >>> tmp.set_vars('func.nii.gz', 'out.feat', 2, 100)
    """
    if high_pass is None:
      high_pass = 100
    high_pass_yn = int(apply_filter)
    data_vars = {'input_file': input_file, 'output_dir': output_dir, 
                'tr': float(tr), 'high_pass': float(high_pass), 
                'high_pass_yn': high_pass_yn}
    self.data_vars = data_vars
    return
  
  def set_stats(self, prewhiten=True, confounds=None):
    ## prewhiten
    self.stats_vars['prewhiten_yn'] = int(prewhiten)
    ## confound evs
    if confounds is None:
      self.stats_vars['confound_yn'] = 0
      self.stats_vars['confound_file'] = ""
    else:
      self.stats_vars['confound_yn'] = 1
      self.stats_vars['confound_file'] = confounds
    return
  
  def add_ev(self, title, fpath, model='gamma', filter=True, derivative=False):
    if len(self.contrasts) != 0:
      raise Exception("Must add all EVs before the contrasts.")
    
    convert = {'none': 0, 'gaussian': 1, 'gamma': 2, 'double-gamma': 3, 'gamma-basis': 4, 'sine-basis': 5, 'fir-basis': 6}
    if model not in convert.values() and model not in convert.keys(): 
      raise Exception("model must be between 0-6 or none, gaussian, gamma, double-gamma, gamma-basis, sine-basis, fir-basis")
    if isinstance(model, str):
      model = convert[model]
  
    filter = int(filter)
    derivative = int(derivative)
    if derivative!=0: raise Exception("derivative for now isn't supported")
    
    self.evs.append({'title': title, 'model': model, 'filter': filter, 'derivative': derivative, 'fpath': fpath})
    self.ev_names.append(title)
    return
  
  def parse_afni_contrast(self, syms):
    contrast = [ 0 for i in range(len(self.evs)) ]
    
    ## FROM AFNI HELP
    #  Stim          = means put +1 in the matrix row for each lag of Stim
    #  +Stim         = same as above
    #  -Stim         = means put -1 in the matrix for for each lag of Stim
    #  # won't do the lag business!!!
    #  Stim[2..7]    = means put +1 in the matrix for lags 2..7 of Stim
    #  3*Stim[2..7]
    
    # so i need to go through each weight
    iter_search = re.finditer("(?P<op>[+-])?(?P<times>[0-9\.]+\ *[*])?\ *(?P<name>[a-zA-Z_]\w*)", syms)
    for m in iter_search:
      d = m.groupdict()
      
      ## Name Check
      if d['name'] is None:
        raise argparse.ArgumentTypeError( "EV name not specified in contrast '%s'" % m.group() )
      elif d['name'] not in self.ev_names:
        raise argparse.ArgumentTypeError( "EV name '%s' from '%s' not found in list of EVs" % (d['name'], m.group()) )
      
      ## Autofill op and times
      if d['op'] is None: d['op'] = '+'
      if d['times'] is None: d['times'] = '1*'
      
      ## Strip the * in times
      d['times'] = d['times'][:-1]
      
      ## Assign the sign to the times
      val = float(d['times'])
      if d['op'] == '-': val = val * -1
      
      ## Get index of EV
      ind = self.ev_names.index(d['name'])
      
      ## Add this on to the contrasts
      contrast[ind] = val
      
    return contrast
  
  def add_contrast(self, title, elems):
    if len(self.evs) == 0: raise Exception("Specify EVs before a contrast")
    if isinstance(elems, str):
      elems = self.parse_afni_contrast(elems)
    elems = [ float(elem) for elem in elems ]
    self.contrasts.append({'title': title, 'elems': elems})
    return

  def compile(self, outfile=None):
    namespace = {}
    namespace.update(self.data_vars)
    namespace.update(self.stats_vars)
    namespace['nevs'] = len(self.evs)
    namespace['ncons'] = len(self.contrasts)
    namespace['evs'] = self.evs
    namespace['contrasts'] = self.contrasts
    
    self.template = Template(file=self.template_file, searchList=[namespace])
    
    self.outfile = outfile
    if outfile is not None:
      with open(outfile, "w") as file:
        file.write(str(self.template))
    
    return self.template
  
  def feat_model(self):
    # this should model the compiled file with feat_model
    if self.outfile is None:
      Exception("outfile is None")
    retcode = os.system("feat_model %s" % self.outfile)
    if retcode != 0:
      print("Non-zero (%i) exit!!!" % retcode)
    return retcode


###
# Parser Arguments
###

# ACTIONS
def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

class store_data(argparse.Action):
  def __call__(self, parser, namespace, value, option_string=None):
    # When a store_true
    if isinstance(value, list) and len(value) == 0:
      value = True
    if not hasattr(namespace, 'data'):
      namespace.data = {}
    namespace.data[self.dest] = value
    return

class store_stats(argparse.Action):
  def __call__(self, parser, namespace, value, option_string=None):
    # When a store_true
    if isinstance(value, list) and len(value) == 0:
      value = True
    if not hasattr(namespace, 'stats'):
      namespace.stats = {}
    namespace.stats[self.dest] = value
    return

class store_ev(argparse.Action):
  def __call__(self, parser, namespace, values, option_string=None):
    if not hasattr(namespace, 'evs'): namespace.evs = []
    
    title  = values[0]
    fpath  = os.path.abspath(values[1])
    
    # Set dict with path and param defaults
    ev =  {'title': title, 'fpath': fpath, 'filter': True, 'derivative': False}
    
    # params example: "model=gamma, filter=true, derivative=false"
    params = values[2] 
    for param in params.split(","):
      [ p.strip() for p in param.split("=") ]
      param.split("=")
      param = param.strip()
        
    iter_search = re.finditer("(?P<param>\w[^=,]*)=(?P<value>\w[^=,]*)", params)
    convs = {'true': True, 
             'false': False} # proly better way to do this?
    for m in iter_search:
      d = m.groupdict()
      #print "%s = %s" % (d['param'], d['value'])
      if d['value'].lower() in convs:
        d['value'] = convs[d['value']]
      elif is_number(d['value']):
        d['value'] = float(d['value'])
      ev[d['param']] = d['value']
    
    if 'model' not in ev:
      parser.error("You must specify the model for EV '%s'" % title)
    
    # Save
    namespace.evs.append(ev)
    
    return

class store_contrast(argparse.Action):
  def __call__(self, parser, namespace, values, option_string=None):
    #values = value.split()
    #if len(values) < 2:
    #  raise argparse.ArgumentTypeError( 'whoops contrasts does not have enough arguments' )
    if not hasattr(namespace, 'contrasts'): namespace.contrasts = [] # TODO: make this an ordered dictionary
    
    name = values[0]
    syms = values[1].replace("SYM: ", "").strip()
    
    namespace.contrasts.append({'title': name, 'elems': syms})
    
    return


if __name__ == "__main__":
  # Setup the argparse for user arguments
  parser = argparse.ArgumentParser(
      description="""
          Prepares for 1st-level fMRI task-analysis with FSL 
          by generating a FSF file.
      """)

  # General
  parser.add_argument("--no-run", action="store_false", dest="run", 
                      default=True, help="Will not run the compiled fsf.")
  # TODO: some force option?
  parser.add_argument('--outfile', action="store", metavar="FILE", 
                        help="Output design matrix.")
  
  # Data
  data_tab = parser.add_argument_group('Data Tab')
  data_tab.add_argument('-i', '--input', action=store_data, metavar="FILE", dest="input_file", 
                        required=True, help="Input functional data")
  data_tab.add_argument('-o', '--outdir', action=store_data, metavar="DIRECTORY", dest="output_dir", 
                        required=True, help="Output feat directory.")
  data_tab.add_argument('--tr', action=store_data, type=float, metavar="SECONDS", 
                        required=True, help="TR for input functional data")
  data_tab.add_argument("--high-pass", action=store_data, type=float, metavar="SECONDS", 
                        help="High-pass filter in seconds")
  af = data_tab.add_argument("--apply-filter", action=store_data, nargs=0, 
                        default=False, help="Whether to high-pass filter the input functional data")

  # Stats
  stats_tab = parser.add_argument_group('Stats Tab')
  pw = stats_tab.add_argument("--prewhiten", action=store_stats, nargs=0, 
                              default=False, help="Prewhiten the data, you probably want this.")
  stats_tab.add_argument("--confounds", action=store_stats, metavar="FILE", 
                          help="Additional confound EVs stored in a text file with each column as an EV")

  # EVs
  evs_group = parser.add_argument_group('Explanatory Variables (EVs)')
  evs_group.add_argument("--stim", action=store_ev, nargs=3, 
                          help="Specifies an EV with 3 arguments: name file params. The file should be FSL's 3 column format (onset, duration, magnitude). Params contains param=value combination with multiple params separated by commas.")

  # Contrasts
  cons_group = parser.add_argument_group('Contrasts', description="These options, must be added after the EVs.")
  exclusive_group = cons_group.add_mutually_exclusive_group()
  exclusive_group.add_argument("--gltfile", action='store', metavar="FILE", 
                               help="CSV file that specifies the contrasts. Each row corresponds to a new contrast, and each column corresponds to an EV. NOT IMPLEMENTED.")
  exclusive_group.add_argument("--glt", action=store_contrast, nargs=2, metavar="name '+ev1 -ev1 ...'", 
                                help="Specifies a contrast using AFNI's SYM format with two arguments. The first argument is the name of the contrast. The second argument is the symbolic expression as in AFNI's 3dDeconvolve without the 'SYM:'. Make sure this second argument is within quotes.")
  
  # Set some of those defaults
  ## see http://stackoverflow.com/questions/21583712/cause-pythons-argparse-to-execute-action-for-default
  ns = argparse.Namespace()
  af(parser, ns, af.default, af.option_strings)
  pw(parser, ns, pw.default, pw.option_strings)
  
  # Parse
  args = parser.parse_args(namespace=ns)
  
  #print(args)
  
  # Checks
  if args.evs is None:
    parser.error("you must specify at least one EV")
  if args.contrasts is None:
    parser.error("you must specify at least one contrast")

  # Defaults
  tmpfile = False
  if args.outfile is None:
    args.outfile = tempfile.mktemp(prefix='tmp_design', suffix='.fsf')
    tmpfile = True

  # Load up the template
  fsf = GenerateFSF('etc/template.fsf')
  fsf.set_data(**args.data)
  fsf.set_stats(**args.stats)
  for ev in args.evs:
    fsf.add_ev(**ev)
  for contrast in args.contrasts:
    fsf.add_contrast(**contrast)
  
  # Compile and save
  t = fsf.compile(args.outfile)
  
  # Run
  if args.run: 
    fsf.feat_model()

  # Clean
  if tmpfile:
    os.remove(tmpfile)

  """
  # TESTING
  parser = argparse.ArgumentParser()
  parser.add_argument("--apply-filter", action=store_data, nargs=0, 
                        default=False, help="Whether to high-pass filter the input functional data")

  args = parser.parse_args(['--apply-filter'])
  """
