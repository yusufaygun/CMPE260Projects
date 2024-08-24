% Yusuf Aygun
% 2020400033
% compiling: yes
% complete: no


:- ['cmpefarm.pro'].
:- init_from_map.

% *1- agents_distance(+Agent1, +Agent2, -Distance) 
% Calculates the Manhattan distance between two agents.
agents_distance(Agent1, Agent2, Distance) :-
    % Extract coordinates of Agent1.
    get_dict(x, Agent1, X1),
    get_dict(y, Agent1, Y1),
    % Extract coordinates of Agent2.
    get_dict(x, Agent2, X2),
    get_dict(y, Agent2, Y2),
    % Calculate Manhattan distance.
    Distance is abs(X1 - X2) + abs(Y1 - Y2).



% *2- number_of_agents(+State, -NumberOfAgents)
% Returns the number of agents in the given state.
number_of_agents(State, NumberOfAgents) :-
    State = [Agents, _, _, _],
    dict_keys(Agents, Keys),
    length(Keys, NumberOfAgents).


% *3- value_of_farm(+State, -Value)
% Calculates the total value of the farm.
value_of_farm(State, Value) :-
    State = [Agents, Objects, _, _],
    % Sum values of all agents.
    dict_values(Agents, AgentValues, 0),
    % Sum values of all objects.
    dict_values(Objects, ObjectValues, 0),
    % Sum total values.
    Value is AgentValues + ObjectValues.

% Helper to sum values from a dictionary.
dict_values(Dict, TotalValue, Accum) :-
    dict_pairs(Dict, _, Pairs),
    foldl(value_sum, Pairs, Accum, TotalValue).

% Foldl helper to add up values.
value_sum(Id-Entity, Acc, NewAcc) :-
    get_dict(subtype, Entity, Subtype),
    (value(Subtype, EntityValue) -> true; EntityValue = 0),
    NewAcc is Acc + EntityValue.




% *4- find_food_coordinates(+State, +AgentId, -Coordinates)
% Finds the coordinates of consumable foods or agents for a specific agent.
find_food_coordinates(State, AgentId, Coordinates) :-
    State = [Agents, Objects, _, _],
    get_dict(AgentId, Agents, Agent),
    get_dict(subtype, Agent, AgentSubtype),
    findall([X, Y], (
        (
            dict_pairs(Objects, _, ObjPairs),
            member(_-Obj, ObjPairs),
            get_dict(subtype, Obj, ObjSubtype),
            get_dict(x, Obj, X),
            get_dict(y, Obj, Y),
            can_eat(AgentSubtype, ObjSubtype)
        );
        (
            dict_pairs(Agents, _, AgentPairs),
            member(OtherAgentId-OtherAgent, AgentPairs),
            OtherAgentId \= AgentId,
            get_dict(subtype, OtherAgent, OtherAgentSubtype),
            get_dict(x, OtherAgent, X),
            get_dict(y, OtherAgent, Y),
            can_eat(AgentSubtype, OtherAgentSubtype)
        )
    ), Coordinates),
    Coordinates \= [].







% *5- find_nearest_agent(+State, +AgentId, -Coordinates, -NearestAgent)
% Finds the nearest agent.
find_nearest_agent(State, AgentId, Coordinates, NearestAgent) :-
    State = [Agents, _, _, _],
    get_dict(AgentId, Agents, Agent),
    get_dict(x, Agent, X),
    get_dict(y, Agent, Y),
    findall(Dist-AId, (
        get_dict(AId, Agents, A),
        AId \= AgentId,
        get_dict(x, A, Ax),
        get_dict(y, A, Ay),
        Dist is abs(X - Ax) + abs(Y - Ay)
    ), Dists),
    sort(Dists, [MinDist-NearestId|_]),
    get_dict(NearestId, Agents, NearestAgent),
    get_dict(x, NearestAgent, Nx),
    get_dict(y, NearestAgent, Ny),
    Coordinates = [Nx, Ny].



% *6- find_nearest_food(+State, +AgentId, -Coordinates, -FoodType, -Distance)
find_nearest_food(State, AgentId, Coordinates, FoodType, Distance) :-
    State = [Agents, Objects, _, _],
    get_dict(AgentId, Agents, Agent),  % Make sure AgentId is valid and exists in Agents
    get_dict(x, Agent, Ax),
    get_dict(y, Agent, Ay),
    find_food_coordinates(State, AgentId, Foods),
    findall(Dist-[X, Y], (
        member([X, Y], Foods),
        Dist is abs(Ax - X) + abs(Ay - Y)
    ), Distances),
    sort(Distances, [MinDist-[Fx, Fy]|_]),
    Coordinates = [Fx, Fy],
    get_object_from_position(Fx, Fy, Objects, Food),
    get_dict(subtype, Food, FoodType),
    Distance = MinDist.




% *7- move_to_coordinate(+State, +AgentId, +X, +Y, -ActionList, +DepthLimit)
% Finds a series of actions to move the agent to a specific coordinate within depth limit.
move_to_coordinate(State, AgentId, X, Y, ActionList, DepthLimit) :-
    move_to_coordinate_helper(State, AgentId, X, Y, [], ActionList, DepthLimit, 0).

% Helper predicate to accumulate actions.
move_to_coordinate_helper(State, AgentId, X, Y, Acc, ActionList, DepthLimit, Depth) :-
    State = [Agents, _, _, _],
    get_dict(AgentId, Agents, Agent),
    get_dict(x, Agent, CurrX),
    get_dict(y, Agent, CurrY),
    (   (CurrX == X, CurrY == Y) -> reverse(Acc, ActionList)  % Target reached
    ;   (   Depth < DepthLimit,
            next_move(CurrX, CurrY, X, Y, Move),
            move(State, AgentId, Move, NewState),
            NewDepth is Depth + 1,
            move_to_coordinate_helper(NewState, AgentId, X, Y, [Move|Acc], ActionList, DepthLimit, NewDepth)
        )
    ).

% Determines the next move based on the current and target positions.
next_move(CurrX, CurrY, TargetX, TargetY, Move) :-
    DiffX is TargetX - CurrX,
    DiffY is TargetY - CurrY,
    (   DiffX > 0 -> Move = move_right
    ;   DiffX < 0 -> Move = move_left
    ;   DiffY > 0 -> Move = move_down
    ;   DiffY < 0 -> Move = move_up
    ).


% *8- move_to_nearest_food(+State, +AgentId, -ActionList, +DepthLimit)
% Finds a series of actions to move the agent to the nearest consumable food.
% Debug version of move_to_nearest_food
move_to_nearest_food(State, AgentId, ActionList, DepthLimit) :-
    find_nearest_food(State, AgentId, [X, Y], FoodType, Distance),
    format('Attempting to move to nearest food: ~w at (~w,~w), Distance: ~d, within DepthLimit: ~d~n', [FoodType, X, Y, Distance, DepthLimit]),
    move_to_coordinate(State, AgentId, X, Y, ActionList, DepthLimit),
    ActionList \= [],
    format('Generated Action List: ~w~n', [ActionList]).




% ?9- consume_all(+State, +AgentId, -NumberOfMoves, -Value, NumberOfChildren +DepthLimit)
% Predicate to guide an agent to consume all reachable food, keeping within movement limits based on map dimensions.
consume_all(State, AgentId, NumberOfMovements, Value, NumberOfChildren) :-
    width(Width),
    height(Height),
    DepthLimit is Width + Height,
    consume_all_helper(State, AgentId, 0, 0, 0, NumberOfMovements, Value, NumberOfChildren, DepthLimit, 0).

% consume_all_helper attempts to consume all reachable food items within the depth limit.
consume_all_helper(State, AgentId, MovAcc, ValAcc, ChildAcc, NumMoves, FinalValue, TotalChildren, DepthLimit, CurrentDepth) :-
    CurrentDepth < DepthLimit,
    move_to_nearest_food(State, AgentId, ActionList, DepthLimit),
    apply_actions(State, ActionList, NewState, AgentId),
    state_value(NewState, ValueGained),
    NewMovAcc is MovAcc + length(ActionList),
    NewValAcc is ValAcc + ValueGained,
    get_children_count(NewState, AgentId, NewChildren),
    NewChildAcc is ChildAcc + NewChildren,
    NewDepth is CurrentDepth + 1,
    consume_all_helper(NewState, AgentId, NewMovAcc, NewValAcc, NewChildAcc, NumMoves, FinalValue, TotalChildren, DepthLimit, NewDepth).

consume_all_helper(State, _, MovAcc, ValAcc, ChildAcc, MovAcc, ValAcc, ChildAcc, _, _).

% get_children_count fetches the number of children for a specific agent.
get_children_count(State, AgentId, Children) :-
    nth0(0, State, Agents),
    get_dict(AgentId, Agents, Agent),
    get_dict(children, Agent, Children).

% Recursively apply actions to update the state.
apply_actions(State, [], State, _).
apply_actions(State, [Action|Actions], FinalState, AgentId) :-
    make_one_action(Action, State, AgentId, NewState),
    apply_actions(NewState, Actions, FinalState, AgentId).

% Calculates the total value of agents and objects in the state.
state_value([Agents, Objects, _, _], TotalValue) :-
    sum_dict_values(Agents, AgentValues),
    sum_dict_values(Objects, ObjectValues),
    TotalValue is AgentValues + ObjectValues.

% sum_dict_values(+Dict, -TotalValue).
% Sums numerical values from a nested dictionary structure.
sum_dict_values(Dict, TotalValue) :-
    dict_pairs(Dict, _, Pairs),
    sum_pairs_values(Pairs, TotalValue).

% Helper to sum values from pairs.
sum_pairs_values([], 0).
sum_pairs_values([_-ValueDict|Rest], Total) :-
    % Assuming each ValueDict has a 'value' key holding the numerical value.
    (get_dict(value, ValueDict, Value) -> true ; Value = 0),
    sum_pairs_values(Rest, Subtotal),
    Total is Subtotal + Value.

