:- initialization(main, main).

main :-
    load_files([
        'test_s02_occlusion_reasoning.pl',
        'test_s02_proximity_reasoning.pl',
        'test_legacy_construction_rbs.pl'
    ], [if(changed)]),
    (   run_tests
    ->  halt(0)
    ;   halt(1)
    ).
