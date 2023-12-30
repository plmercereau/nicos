{
  m1 = {
    label = "Apple M1";
    path = ./m1-m2.nix;
  };
  m2 = {
    label = "Apple M1";
    path = ./m1-m2.nix;
  };
  x86 = {
    label = "x86 processor";
    path = ./x86.nix;
  };
}
