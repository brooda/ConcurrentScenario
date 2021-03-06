:- module(next_state, 
    [
        get_next_state/7
	]).
:- use_module(mns).
:- use_module(compound_executable).
:- use_module(occlusion).
:- use_module(potentially_executable).
:- use_module(logic_formula_satisfiability).

%compound_executable_atomic(Compound_Action, Time, Action_Domain, Fluent_Assignments)

get_nonempty_action_decomposition(Compound_Action, Time, Action_Domain, Fluent_Assignments, Action_Decomposition) :-
    mns(Compound_Action, Time, Action_Domain, Fluent_Assignments, Action_Decomposition),
    dif(Action_Decomposition, []).
    % get MNS sample using compound executable


% generate all possible assignments
% use the following predicate get_sample_fluent_assignment
% should determine all fluents taking part in: 
%   Fluent_Assignments
%   next time observation if any
%   occlusion list (already found)
% must satisfy:
%   the only variables that change in 2^n ways are those from Unique_Occlusion_List and those in upcoming observation
%       that are new, they're absent in Fluent assignments and occlusion
%   others must remain intact as in Fluent_Assignments
%   the conjunction of all consequences of MNS_Executed_Action (extract Consequence from compound_executable_atomic_get_assignment?)
%   Observation from next time must hold so if there are new fluents (they were smthing at the beginning but only now we know)
vary_fluents([], Fluent_Assignments, [], Fluent_Assignments).
vary_fluents([], Fluent_Assignments, [Observation | Next_Observation], New_Assignment) :-
    vary_fluents([], Fluent_Assignments, Next_Observation, Less_New_Assignment),
    (put_assoc(Observation, Less_New_Assignment, true, New_Assignment) ; put_assoc(Observation, Less_New_Assignment, false, New_Assignment)).
vary_fluents([OCL | Occlusion_List], Fluent_Assignments, Next_Observation, New_Assignment) :-
    get_assoc(OCL, Fluent_Assignments, _) ->
    (   del_assoc(OCL, Fluent_Assignments, _, Less_Fluent),
        vary_fluents(Occlusion_List, Less_Fluent, Next_Observation, Less_New_Assignment),
        (put_assoc(OCL, Less_New_Assignment, true, New_Assignment) ; put_assoc(OCL, Less_New_Assignment, false, New_Assignment))
    )
    ;
    (
        vary_fluents(Occlusion_List, Fluent_Assignments, Next_Observation, Less_New_Assignment),
        (put_assoc(OCL, Less_New_Assignment, true, New_Assignment) ; put_assoc(OCL, Less_New_Assignment, false, New_Assignment))
    ).



% input: Occlusion_List, Fluent_Assignments, Next_Observation
% output: New_Assignment
get_valid_assignment(Occlusion_List, Fluent_Assignments, Next_Observation, New_Assignment) :-
    findall(Fluent, (get_sample_fluent_from_tree(Next_Observation, Fluent), not(get_assoc(Fluent, Fluent_Assignments, _)), not(member(Fluent, Occlusion_List, _))), Fluents),
    sort(Fluents, Unique_Fluents),
    vary_fluents(Occlusion_List, Fluent_Assignments, Unique_Fluents, New_Assignment),
    logic_formula_satisfied(Next_Observation, New_Assignment).

% input: Occlusion_List, Fluent_Assignments
% output: New_Assignment
get_valid_assignment(Occlusion_List, Fluent_Assignments, New_Assignment) :-
    vary_fluents(Occlusion_List, Fluent_Assignments, [], New_Assignment).

conjunct(Statement, [], Statement).
conjunct(Statement, Acc1, and(Statement, Acc1)).

get_next_state(Time, Fluent_Assignments, Observations, Actions, Action_Domain, MNS_Executed_Action, New_Assignment) :-
    get_assoc(Time, Actions, ACS_Compound_Action)
    ->
    (
        findall(
            Action,
            (member(Action, ACS_Compound_Action), potentially_executable_atomic(Time, Action_Domain, Fluent_Assignments, Action)),
            Potentailly_Executable_Subset),
        dif(Potentailly_Executable_Subset, []),
        
        get_nonempty_action_decomposition(Potentailly_Executable_Subset, Time, Action_Domain, Fluent_Assignments, MNS_Executed_Action),
        findall(Fluent, (member(Action, MNS_Executed_Action), get_occlusion(Action, Action_Domain, Fluent)), Occlusion_List),
        sort(Occlusion_List, Unique_Occlusion_List),
        Next_Time is Time + 1,
        %prepare causes postconditions
        
        findall(
            Causes_Condition,
            (member(Action, MNS_Executed_Action),get_assoc(Action, Action_Domain, Action_Description),  get_assoc("causes", Action_Description, (Causes_Condition, _))),
            Causes_Conditions),
            
        (get_assoc(Next_Time, Observations, Next_Observation)
        ->
            get_valid_assignment(Unique_Occlusion_List, Fluent_Assignments, Next_Observation, New_Assignment),
            (
                Causes_Conditions = []
                -> true
                ; 
                (
                    foldl(conjunct, Causes_Conditions, true, Consequence),
                    logic_formula_satisfied(Consequence, New_Assignment)
                )
            )
        ;
        get_valid_assignment(Unique_Occlusion_List, Fluent_Assignments, New_Assignment),
        (
        Causes_Conditions = []
        -> true
        ;
        (
                foldl(conjunct, Causes_Conditions, true, Consequence),
                % write(Time),write(" "),writeln(Consequence),assoc_to_list(New_Assignment,L),writeln(L),
                logic_formula_satisfied(Consequence, New_Assignment)
            )
        ))
    )
    ;
    (
        MNS_Executed_Action = [],
        Next_Time is Time + 1,
        (get_assoc(Next_Time, Observations, Next_Observation)
        ->
            logic_formula_satisfied(Next_Observation, Fluent_Assignments),
            New_Assignment = Fluent_Assignments
        ;
            New_Assignment = Fluent_Assignments
        )
    ).