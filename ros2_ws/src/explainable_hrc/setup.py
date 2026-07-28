from setuptools import find_packages, setup

package_name = 'explainable_hrc'

setup(
    name=package_name,
    version='0.1.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
         ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    tests_require=['pytest'],
    test_suite='test',
    zip_safe=True,
    maintainer='ExplainableHRC maintainers',
    maintainer_email='lily@example.com',
    description='Deterministic safety decision prototype for ExplainableHRC.',
    license='MIT',
    entry_points={
        'console_scripts': [
            'safety_decision_node = '
            'explainable_hrc.safety_decision_node:main',
        ],
    },
)
