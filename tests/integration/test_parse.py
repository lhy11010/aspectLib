import os
from shilofue import Parse


def test_parse_from_file():
    # test_file = 'fixtures/parse_test.prm'
    test_file = os.path.join(os.path.dirname(__file__), 'fixtures', 'parse_test.prm')
    assert(os.access(test_file, os.R_OK))
    with open(test_file, 'r') as fin:
        inputs = Parse.ParseFromDealiiInput(fin)
    assert(inputs['Dimension'] == '2')
    assert(inputs['Use years in output instead of seconds'] == 'true')
    assert(inputs['End time'] == '40.0e6')
    assert(inputs['Additional shared libraries']
           == '/home/lochy/ASPECT_PROJECT/aspect_plugins/subduction_temperature2d/libsubduction_temperature2d.so, /home/lochy/ASPECT_PROJECT/aspect_plugins/prescribe_field/libprescribed_temperature.so')


def test_parse_to_new_case():
    test_file = os.path.join(os.path.dirname(__file__), 'fixtures', 'parse_test.prm')
    assert(os.access(test_file, os.R_OK))
    with open(test_file, 'r') as fin:
        inputs = Parse.ParseFromDealiiInput(fin)
    _config = {'names': [['End time'], ['Material model', 'Visco Plastic', 'Reset corner viscosity constant']],
               'values': ['80.0e6', '1e21']}
    Case = Parse.CASE(inputs, _config)
    assert(Case.idict['End time'] == '80.0e6')
    assert(Case.idict['Material model']['Visco Plastic']['Reset corner viscosity constant'] == '1e21')
    Case()
    assert(os.path.isfile('foo'))
    os.remove('foo')
