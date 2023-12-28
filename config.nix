{
  projectRoot = ./.;
  adminKeys = [
    # badger
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyxrQiE8bx1R9SG4fuNebXP8oq1duReM7E7W2M0i0fsC3PrKwQ6c9R4qzNQLREeWwtCWV0KEl0K+iriiIPa7D5psEASJapGyi5NtqEqZbM+a8BGQNdy82zEU4xU6IA4GyjxqPb/0zRiEh//4RuePZGNItW2Gl+1ZvOA1UTsHZKpGgZxWewoGdtm6EwscTy+5A4uanFWmxtpajy5J1GVR038quQLszSsTfTRr0gA80+uQbahHlGmP9HlyXrjaeKtSz9XTT95XmC/rVJkIKBYEIEf2fyV+O3hB1cxh+fb/lHFqoIJrES1qU4TAzs58Ioj0Jd3xlPGa96VJewrNXKbFjP"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGd6o/NuO04nLqahrci03Itd/1yoK76ZpzKGgpwAEctb"
    # puffin
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzHVK8afzDVzWFRhditSwYRHbAXxFTSH2UDjCZUcKLwkTvUkSjV64FIjWQ8ftu5FreY5LFuwLiNfyFRlWAxYrTHs2pjrjr/iLNROc/PbFy8pA+KupFkB9DqG2MUyzUuUdcO57mW0bO3xXkoXzaqhQ0/rEnwp5z9QSOw8HG2/C8rDxQ8Er+gKK3nPgnzjXyut9JP28/+++dSPXFvWXdT4zF2lrF4iKhUIsYZtF8wjUPVWsKzt3FBkshFkTvlFGbtMzxAQIhHrpmQjopQXhue+ZQpZmXI0wOonzXW/AUzFvMyekrYy0CFqyWnL5xygxYXfvgByffHwAZuX/fDhQZrn7/56f9BNyylkr2GFKlMR8OqSh8HqxNQDz24yww93B6+ZceFIubfMYGNs3TcQREllJqhOMmd8OyjZljmL+zajXXKmHjeh2bibw+klB3RBBULy9TM0am1OD6xqM+N5o7Uj3kE7mnSbiajWGUssSlkSlvMl/kO32XK8VUDyvMML7V27zK4g2kScFPo4fQiazWj4X0OOBYhiWGXkjvm7ws52XNRkMp+NYHjx+F7XBzG7qiyfTDGPcA4aVbwGuIjV20081UmaNXw9JrrUdQ4hQrl0JK4COe6XV4wIarhPCtR+tMHDdf0hxY8ExXT/WerK+9amqOPGcXS60XdohvXyNmJ5OX1Q=="
  ];
  extraModules = [./shared.nix];
  nixos = {
    enable = true;
    path = "./hosts-nixos";
  };
  darwin = {
    enable = true;
    path = "./hosts-darwin";
  };
  users = {
    enable = true;
    path = "./users";
  };
  wifi = {
    enable = true;
    path = "./wifi";
  };
  builders = {
    enable = true;
    path = "./builder";
  };
}
