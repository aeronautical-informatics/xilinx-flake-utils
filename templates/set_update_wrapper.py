import os
from pathlib import Path
from string import Template
import sys


seperator = ''


def main():

    proj_dir = str(sys.argv[1])
    proj_dir = seperator.join([proj_dir, '/scripts/'])
    proj_name = str(sys.argv[2])
    
    script_dir = os.path.dirname(__file__)
    #file_path = script_dir / "update_wrapper.tcl"
    file_path = seperator.join([script_dir, '/update_wrapper_template.tcl'])

    file = open(file_path, 'r+')

    data = file.read()
    t = Template(data)
    t_string = t.safe_substitute(name=proj_name)

    file.close()

    new_file_path = Path(proj_dir) / "update_wrapper.tcl"
    new_file = open(new_file_path, 'w')
    new_file.write(t_string)
    new_file.close()

if __name__ == '__main__':
    main()
