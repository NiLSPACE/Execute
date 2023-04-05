local time = os.clock();
local iterations = 0;
while (os.clock() < time + 3) do
    iterations = iterations + 1
end

print(iterations)