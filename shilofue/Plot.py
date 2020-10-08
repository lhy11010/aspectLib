import sys
import os
import json
import re
import shilofue.json
import warnings
import numpy as np
from importlib import resources
from shilofue.Utilities import JsonOptions, ReadHeader, ReadHeader2, UNITCONVERT
from matplotlib import pyplot as plt

class LINEARPLOT():
    '''
    LINEARPLOT():
    class for LINEARPLOT

    '''

    def __init__(self, _name, kwargs):
        '''
        _name(str):
            name of the plotting
        kwargs:
            unit_convert(fun):
                a unit_convert function, default is None
        '''
        self.name = _name
        _json_dir = kwargs.get('json_dir', None)
        self.options = JsonOptions(_name, _json_dir)
        self.UnitConvert = kwargs.get('unit_convert', None)
        self.dim = kwargs.get('dim', 2)  # dimension
        assert(self.dim in [1, 2, 3])  # dimension must be 1, 2, 3
        # Read plot options from a json file
        _jsonfile = kwargs.get('json', None)
        if _json_dir is not None:
            _jsonfile = os.path.join(_json_dir, self.name + '.json')
            with open(_jsonfile, 'r') as fin:
                self.configs = json.load(fin)
        else:
            # default is to read from '.json' in shilofue.json
            with resources.open_text(shilofue.json, self.name + '.json') as fin:
                self.configs = json.load(fin)
    
    def __call__(self):
        '''
        '''
        pass

    class DataNotFoundWarning(UserWarning):
        # handle the circumstance that one data field is not found,
        # but continue the plot
        pass

    def ReadHeader(self, _filename):
        '''
        Read header information from file.
        An example of string is:
        '# 1: Time (years)'
        Args:
            _filename(str):
                filename for data file
        '''
        assert(os.access(_filename, os.R_OK))
        with open(_filename, 'r') as fin:
            _texts = fin.readlines()  # read the text of the file header
        self.header = ReadHeader(_texts)

    def ReadData(self, _filename):
        '''
        Read Data
        Attributes:
            _filename(string):
                filename for data file
        '''
        assert(os.access(_filename, os.R_OK))  # read in data
        # self.data = np.genfromtxt(_filename, comments='#')
        
        # import data via numpy buid in method
        # todo catch warning of empty file and return 1
        with warnings.catch_warnings(record=True) as w:
            self.data = np.genfromtxt(_filename, comments='#')
            if (len(w) > 0):
                assert(issubclass(w[-1].category, UserWarning))
                assert('Empty input file' in str(w[-1].message))
                warnings.warn('ReadData: %s, abort' % str(w[-1].message))
                return 1
        
        if len(self.data.shape) == 1:
            # only one row, expand it too 2-d array
            self.data = np.array([self.data])
        return 0
        

    def ManageData(self):
        '''
        manage data, get new data for this class
        for the base class, this method simply takes the combination
        of self.data
        Returns:
            _data_list(list):
                list of data for ploting
        '''
        _data_list = []
        for i in range(self.data.shape[1]):
            _data_list.append(self.data[:, i])
        return _data_list
    
    def PlotCombine(self, _data_list, _fileout, **kwargs):
        '''
        Combine all plottings
        Arguments:
            _data_list(list<ndarray>):
                list of data, each member is a set of data for
                some variable
            _fileout(str):
                name of the output file
            **kwargs:
                title(str):
                    title of the ploting
        Returns:
            _filename(string):
                name of the plotting created
        Raises:
            AssertionError:
                if size of canvas doesn't match number of plottings
        '''
        # plot configuration
        assert(type(_data_list) is list)
        _canvas = self.configs.get('canvas', [1, 1])
        assert(type(_canvas) is list and len(_canvas) == 2)
        _types = self.configs['types']  # types of plotting
        assert(type(_types) is list and
            _canvas[0] * _canvas[1] >= len(_types))  # size of canvas match size of _types
        _size = self.configs.get('size', (12, 12))  # size of the plot
        _title = kwargs.get('title', None)  # get title
        # plot
        fig, axs = plt.subplots(_canvas[0], _canvas[1], figsize=_size)
        for i in range(len(_types)):
            # find the right axis
            if _canvas[0] == 1 and _canvas[1] == 1:
                # if canvas is single, the axs is an axis
                _ax = axs
            elif _canvas[0] == 1 or _canvas[1] == 1:
                # if canvas is a number, then axs is 1-d array
                _ax = axs[i]
            else:
                # if canvas is two dimensional, axs is also two dimensional
                _id1 = i // _canvas[1]
                _id2 = i % _canvas[1]
                _ax = axs[_id1, _id2]
            # find options for plot
            _type = _types[i]
            if type(_type) == str:
                _opt = self.options[_type]  # get the plot options
                self.Plot(_data_list, _ax, _opt)
            elif type(_type) == list:
                # when _type is a list, plot multiple lines in a subplot
                for _subtype in _type:
                    assert(type(_subtype) == str)
                    _opt = self.options[_subtype]  # get the plot options
                    self.Plot(_data_list, _ax, _opt)
        fig.tight_layout()
        fig.savefig(_fileout)
        plt.close(fig)
        return _fileout

    def Plot(self, _data_list, _ax, _opt):
        '''
        Plot(self, fig, ax, _opt):
        Plot a line plotting from data
        Arguments:
            _data_list(list<ndarray>):
                list of data, each member is a set of data for
                some variable
            _ax(axis):
                an axis object from matplotlib
            _opt(dict):
                dictionary for plot options
        Returns:
            _ax(axis):
                the same as input
        '''
        # Options for plot
        # xname and yname are labels for x and y axis,
        # color is the color for ploting
        # label is the label for legend
        # line is the type of line for plotting
        _xname = _opt.get('xname', 'Time')
        _yname = _opt.get('yname', 'Number_of_mesh_cells')
        _color = _opt.get('color', 'r')
        _label = _opt.get('label', 'default')
        _line = _opt.get('line', '-')
        _invert_x = _opt.get('invert_x', 0)  # invert x axis
        _invert_y = _opt.get('invert_y', 0)
        _log_x = _opt.get('log_x', 0)  # plot x as log
        _log_y = _opt.get('log_y', 0)  # plot y as log
        # then column is determined
        # by header information
        _colx = self.header[_xname]['col']
        try:
            _coly = self.header[_yname]['col']
        except KeyError:
            # there is no such field in the file
            # give out a warning, continue with the next plot
            warnings.warn('The field %s doesn\'t exist. We will keep ploting,\
but you will get a blank one for this field name' % _yname,
                           self.DataNotFoundWarning)
            return
        _unitx = self.header[_xname]['unit']
        _unity = self.header[_yname]['unit']
        _x = _data_list[_colx]
        _y = _data_list[_coly]
        # get the unit for plot
        _unit_x_plot = _opt.get('xunit', _unitx)
        _unit_y_plot = _opt.get('yunit', _unity)
        # convert the unit
        if self.UnitConvert is not None and _unit_x_plot != _unitx:
            x_convert_ratio = self.UnitConvert(_unitx, _unit_x_plot)
        else:
            x_convert_ratio = 1.0
        if self.UnitConvert is not None and _unit_y_plot != _unity:
            y_convert_ratio = self.UnitConvert(_unity, _unit_y_plot)
        else:
            y_convert_ratio = 1.0
        # construct label from xname and yname
        # put in unit
        if _unit_x_plot is not None:
            _xlabel = re.sub("_", " ", _xname) + ' (' + _unit_x_plot + ')'
        else:
            _xlabel = re.sub("_", " ", _xname)
        if _unit_y_plot is not None:
            _ylabel = re.sub("_", " ", _yname) + ' (' + _unit_y_plot + ')'
        else:
            _ylabel = re.sub("_", " ", _yname)
        if _log_x and _log_y:
            _ax.loglog(_x*x_convert_ratio, _y*y_convert_ratio, _line, color=_color, label=_label)
        elif _log_x:
            _ax.semilogx(_x*x_convert_ratio, _y*y_convert_ratio, _line, color=_color, label=_label)
        elif _log_y:
            _ax.semilogy(_x*x_convert_ratio, _y*y_convert_ratio, _line, color=_color, label=_label)
        else:
            _ax.plot(_x*x_convert_ratio, _y*y_convert_ratio, _line, color=_color, label=_label)
        _ax.set(xlabel=_xlabel, ylabel=_ylabel)
        if _invert_x and ~_ax.xaxis_inverted():
            _ax.invert_xaxis()
        if _invert_y and ~_ax.yaxis_inverted():
            _ax.invert_yaxis()
        _ax.legend()


class STATISTICS_PLOT(LINEARPLOT):
    '''
    Class for plotting depth average file.
    This is an inheritage of the LINEARPLOT class

    Attributes:
    Args:
    '''
    def __init__(self, _name, **kwargs):
        LINEARPLOT.__init__(self, _name, kwargs)  # call init from base function
    
    def __call__(self, _filename, **kwargs):
        '''
        Read and plot
        Attributes:
            _filename(string):
                filename for data file
        Returns:
            _fileout(string):
                filename for output figure
        '''
        _fileout = kwargs.get('fileout', _filename + '.pdf')
        
        # inteprate header information
        self.ReadHeader(_filename)

        # Read data
        # todo: catch possible vacant file
        state=self.ReadData(_filename)
        if state == 1:
            return None

        # manage output data
        _data_list = self.ManageData()
        _fileout = self.PlotCombine(_data_list, _fileout)
        return _fileout


class DEPTH_AVERAGE_PLOT(LINEARPLOT):
    '''
    Class for plotting depth average file.
    This is an inheritage of the LINEARPLOT class

    Attributes:
    Args:
    '''
    def __init__(self, _name, **kwargs):
        LINEARPLOT.__init__(self, _name, kwargs)  # call init from base function
        self.time_step_length = None
        # both these two arrays have the length of total time steps
        # the first records the time for each time step
        # the second points to the actual step within data
        self.time_step_times = None
        self.time_step_indexes = None

    def __call__(self, _filename, **kwargs):
        '''
        Read and plot
        Attributes:
            _filename(string):
                filename for data file
        Returns:
            _fileout(string or list):
                filename for output figure
        future:
            add in option for unit
        '''
        _fileout = kwargs.get('fileout', _filename + '.pdf')
        _time = kwargs.get('time', 'last')  # default is 'last' which means the last step
        self.ReadHeader(_filename)  # inteprate header information
        self.ReadData(_filename)  # read data
        self.ManageUnits()  # mange unit to output
        self.SplitTimeStep()  # split time step data
        # work out the name of output files
        _fname_base = _fileout.rpartition('.')[0]
        _fname_type = _fileout.rpartition('.')[2]
        _fname_list = []  # initialize a list for return
        if type(_time) in [float, int]:
            _time_list = [_time]
        elif type(_time) in [list, np.ndarray]:
            _time_list = _time
        else:
            raise TypeError('type of time needs to be in [float, int, list, np.ndarrayy]')
        for _t in _time_list:
            if type(_t) not in [float, int]:
                raise TypeError('type of values in time needs to be in [float, int, list, np.ndarrayy]')
            _data_list = self.ManageData(_t)  # manage output data
            _t_in_myr = _t * self.UnitConvert(self.header['time']['unit'], 'myr')
            _fname = "%s_t%.8e.%s" % (_fname_base, _t_in_myr, _fname_type)
            _figure_title = "Detph Average, t = %.10f myr" % _t_in_myr
            _fname = self.PlotCombine(_data_list, _fname, title=_figure_title)
            _fname_list.append(_fname)
        if len(_fname_list) == 0:
            # if there is only one name, just return this name
            return _fname_list[0]
        else:
            return _fname_list

    def ReadHeader(self, _filename):
        '''
        Read header information from file.
        overload base function, use ReadHeader2
        function in utilities.py
        Args:
            _filename(str):
                filename for data file
        '''
        assert(os.access(_filename, os.R_OK))
        with open(_filename, 'r') as fin:
            _texts = fin.readlines()  # read the text of the file header
        self.header = ReadHeader2(_texts)

    def SplitTimeStep(self):
        '''
        split time steps, since the data is a big chunck
        '''
        _time_step_times = []  # initialize
        _time_step_indexes = []
        _col_time = self.header['time']['col']
        _col_depth = self.header['depth']['col']
        _times = self.data[:, _col_time]
        _depths = self.data[:, _col_depth]
        # get the lenght of a single time step
        for i in range(1, _depths.size):
            if _depths[i] < _depths[i-1]:
                self.time_step_length = i
                break
            elif i == _depths.size - 1:
                # as the exiting value from python is simply _depths.size - 1
                self.time_step_length = i + 1
        # make a ndarray of different value of time
        _step_times = [_times[_idx] for _idx in range(0, _times.size, self.time_step_length)]
        i = 0  # first sub list for first step
        _time_step_times.append(_step_times[0])
        _time_step_indexes.append([0])
        # loop to group data at the same step
        for j in range(1, len(_step_times)):
            _time = _step_times[j]
            if abs(_time - _step_times[j-1]) > 1e-16:
                _time_step_indexes.append([])
                _time_step_times.append(_time)
                i += 1
            _time_step_indexes[i].append(j)
        # both these two arrays have the length of total time steps
        # the first records the time for each time step
        # the second points to the actual step within data
        self.time_step_times = np.array(_time_step_times)
        self.time_step_indexes = _time_step_indexes
    
    def ManageData(self, _time):
        '''
        manage data, get new data for this class
        Returns:
            _data_list(list):
                list of data for ploting
            _time(float):
                time of plotting
        '''
        _data_list = []
        _time_step = np.argmin(abs(self.time_step_times - _time))  # time_step
        _index0 = self.time_step_indexes[_time_step][-1] * self.time_step_length
        if _time_step == len(self.time_step_times) - 1:
            # this is the last step
            _index1 = self.data.shape[0]
        else:
            _index1 = self.time_step_indexes[_time_step + 1][0] * self.time_step_length
        for i in range(self.data.shape[1]):
            _data_list.append(self.data[_index0 : _index1, i])
        # get the super adiabatic temperature
        _col_temperature = self.header['temperature']['col']
        _col_adiabatic_temperature = self.header['adiabatic_temperature']['col']
        _super_adiabatic_temperature = self.data[_index0 : _index1, _col_temperature] - self.data[_index0 : _index1, _col_adiabatic_temperature]
        _data_list.append(_super_adiabatic_temperature)
        self.header['super_adiabatic_temperature'] = {}
        self.header['super_adiabatic_temperature']['col'] = self.header['total_col']
        self.header['super_adiabatic_temperature']['unit'] = 'K'
        self.header['total_col'] += 1
        return _data_list
    
    def ManageUnits(self):
        '''
        manage units, get units for data.
        This is due to the bad form of the header of this file
        '''
        self.header['time']['unit'] = 'yr'
        self.header['depth']['unit'] = 'm'
        self.header['temperature']['unit'] = 'K'
        self.header['viscosity']['unit'] = 'Pa s'
        self.header['velocity_magnitude']['unit'] = 'm/yr'
        if self.dim == 2:
            self.header['vertical_heat_flux']['unit'] = 'mw/m'
        elif self.dim == 3:
            self.header['vertical_heat_flux']['unit'] = 'mw/m^2'


class NEWTON_SOLVER_PLOT(LINEARPLOT):
    '''
    Class for plotting depth average file.
    This is an inheritage of the LINEARPLOT class

    Attributes:
    Args:
    '''
    def __init__(self, _name, **kwargs):
        LINEARPLOT.__init__(self, _name, kwargs)  # call init from base function

        # initiate
        # if step is None, then plot for all steps, otherwise plot for a step
        self.step = None
    
    def __call__(self, _filename, **kwargs):
        '''
        Read and plot
        Attributes:
            _filename(string):
                filename for data file
        Returns:
            _fileout(string):
                filename for output figure
        '''
        _fileout = kwargs.get('fileout', _filename + '.pdf')
        self.ReadHeader(_filename)  # inteprate header information

        # todo, catch possible vacant file
        state = self.ReadData(_filename)  # read data
        if state == 1:
            return None

        # manage output data
        _data_list = self.ManageData()

        # figure out name of file 
        if self.step is None:
            # plot for all
            _fname = _fileout
        else:
            _fname_base = _fileout.rpartition('.')[0]
            _fname_type = _fileout.rpartition('.')[2]
            _fname = "%s_s%07d.%s" % (_fname_base, self.step, _fname_type)

        # plot
        _fileout = self.PlotCombine(_data_list, _fname)
        return _fileout
    
    def GetStep(self, step):
        '''
        Get time step
        Inputs:
            step(int): index of time step
        '''
        self.step = step
    
    def ManageData(self):
        '''
        manage data, get new data for this class
        Returns:
            _data_list(list):
                list of data for ploting
        '''
        if self.step is None:
            _data_list = self.ManageDataAll()
        else:
            _data_list = self.ManageDataStep()
        return _data_list

    def ManageDataStep(self):
        '''
        manage data for a single step
        Returns:
            _data_list(list):
                list of data for ploting
        ''' 
        _data_list = []

        # get list of step        
        col_step = self.header['Time_step_number']['col']
        mask_step = (self.data[:, col_step] == self.step)
        for i in range(self.data.shape[1]):
            _data_list.append(self.data[mask_step, i])
        return _data_list
    
    def ManageDataAll(self):
        '''
        manage data for a single step
        Returns:
            _data_list(list):
                list of data for ploting
        ''' 
        _data_list = []
        for i in range(self.data.shape[1]):
            _data_list.append(self.data[:, i])
        
        # get number of nonlinear iteration
        nni = np.array([i for i in range(self.data.shape[0])])
        _data_list.append(nni)
        # mend header
        self.header['Number_of_nonlinear_iteration'] = {}
        self.header['Number_of_nonlinear_iteration']['col'] = self.header['total_col']
        self.header['Number_of_nonlinear_iteration']['unit'] = None
        self.header['total_col'] += 1
        return _data_list


def ProjectPlot(_project_dict, _project_dir, _file_type, **kwargs):
    '''
    Plot figures for all cases in this project
    Inputs:
        kwargs:
            update(True or False): if True, update existing figures
    '''
    update = kwargs.get('update', False)
    # Init the UnitConvert class
    UnitConvert = UNITCONVERT()

    # plot statistics ouput
    Statistics = STATISTICS_PLOT('Statistics', unit_convert=UnitConvert)
    # depth average output
    DepthAverage = DEPTH_AVERAGE_PLOT('DepthAverage', unit_convert=UnitConvert)
    # newton solver output
    # This is a little bit confusing to myself.
    # But yes, we need two of them to do different type of plot.
    NewtonSolverStep = NEWTON_SOLVER_PLOT('NewtonSolverStep')
    NewtonSolver = NEWTON_SOLVER_PLOT('NewtonSolver')

    for key, value in _project_dict.items():
        if key == 'cases':
            _dir = _project_dir
        else:
            # groups, future
            _dir = os.path.join(_project_dir, key)
        for _case in value:
            # cases
            _case_dir = os.path.join(_dir, _case)
            _case_output_dir = os.path.join(_case_dir, 'output')
            _case_img_dir = os.path.join(_case_dir, 'img')
            if not os.path.isdir(_case_img_dir):
                # make img folder if not exists
                os.mkdir(_case_img_dir)

            # plot statistic
            _statistic_file = os.path.join(_case_output_dir, 'statistics')
            _ofile = os.path.join(_case_img_dir, 'Statistics.'+ _file_type)
            if os.path.isfile(_statistic_file) and (not os.path.isfile(_ofile) or update is True):
                try:
                    Statistics(_statistic_file, fileout=_ofile)
                except Exception as e:
                    raise Exception("Plot statistics file failed for %s, please chech file content.\
One option is to delete incorrect file before running again" % _statistic_file) from e
                else:
                    print('Plot has been generated: ', _ofile)  # screen output

            # plot depth-average
            _depth_average_file = os.path.join(_case_output_dir, 'depth_average.txt')
            _time = 0.0
            _ofile_route = os.path.join(_case_img_dir, 'DepthAverage.%s' % _file_type)
            _ofile = os.path.join(_case_img_dir, 'DepthAverage_t%.8e.%s' % (_time, _file_type))  # ofile has the exact time
            if os.path.isfile(_depth_average_file) and (not os.path.isfile(_ofile) or update is True):
                # check for ofile here is not precist, not intuitive. future: change the implementation
                try:
                    _ofile_exact = DepthAverage(_depth_average_file, fileout=_ofile_route, time=_time)
                except Exception as e:
                    raise Exception("Plot DepthAverage file failed for %s, please chech file content.\
One option is to delete incorrect file before running again" % _depth_average_file) from e
                else:
                    if _ofile_exact is not None:
                        # output when there is file generated
                        print('Plot has been generated: ', _ofile_exact)  # screen output
            
            # add solver output
            # plot newton solver output
            _solver_file = os.path.join(_case_output_dir, 'solver_output')
            _ofile_route = os.path.join(_case_img_dir, 'NewtonSolverStep.%s' % _file_type)
            # plot step0
            _step = 0
            NewtonSolverStep.GetStep(_step)
            _ofile = os.path.join(_case_img_dir, 'NewtonSolverStep_s%07d.%s' % (_step, _file_type))
            if os.path.isfile(_solver_file) and (not os.path.isfile(_ofile) or update is True):
                # check for ofile here is not precist, not intuitive. future: change the implementation
                try:
                    _ofile_exact = NewtonSolverStep(_solver_file, fileout=_ofile_route)
                except Exception as e:
                    raise Exception("Plot NewtonSolver file failed for %s, please chech file content.\
    One option is to delete incorrect file before running again" % _solver_file) from e
                else:
                    if _ofile_exact is not None:
                        # output when there is file generated
                        print('Plot has been generated: ', _ofile_exact)  # screen output
            # plot whole history
            _ofile = os.path.join(_case_img_dir, 'NewtonSolver.%s' % _file_type)
            if os.path.isfile(_solver_file) and (not os.path.isfile(_ofile) or update is True):
                # check for ofile here is not precist, not intuitive. future: change the implementation
                try:
                    _ofile_exact = NewtonSolver(_solver_file, fileout=_ofile)
                except Exception as e:
                    raise Exception("Plot NewtonSolver file failed for %s, please chech file content.\
    One option is to delete incorrect file before running again" % _solver_file) from e
                else:
                    if _ofile_exact is not None:
                        # output when there is file generated
                        print('Plot has been generated: ', _ofile_exact)  # screen output
        pass
    