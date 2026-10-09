## Agent skills

- `home/dot_config/exact_agents/vendor_skills/` holds only unmodified copies of
  third-party skills, each with its upstream `LICENSE.txt`.
- Once a third-party skill is adapted, move it to
  `home/dot_config/exact_agents/skills/`. Keep its `LICENSE.txt` and add a
  copyright line for the modifications.
- Point the matching `home/exact_dot_agents/exact_skills/symlink_<name>.tmpl` at
  the skill's current location.
