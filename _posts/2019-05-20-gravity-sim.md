# Gravity Sim

I've been working on a gravity simulator in Rust for a while using a game engine called ggez. You can find it here.
https://github.com/mkhan45/gravity-sim

A more in-depth code overview can be found here:
https://mkhan45.github.io/blog/gravity-sim-code

You can find an in progress web port here:

https://mkhan45.github.io/gravity-sim-rs/

## What it does

My gravity simulator simulates the gravity of point masses and completely inelastic collisions with conserved momentum. You can place bodies with a set radius, density, and velocity, and delete them by right clicking on them. You'll see a green prediction line for them, and they leave a blue trail. Because it simulates point masses, you can simulate not only orbits, but also just random particles.

![](/resources/gravity/point_masses.gif)


## Cool Stuff

### Patterns and step size
You can also adjust the prediction's speed, and making it really fast reveals a lot about the simulation's behavior and inaccuracies. 

![](/resources/gravity/prediction_inaccuracy.gif)

In the simulation, the angle of the elliptical orbit keeps changing, and that doesn't happen in real life. The reason for this is that computational integration always has some inaccuracy. To fix it, I added a way to adjust the step size. Lower step size means higher accuracy, but it's also much slower. 

![](/resources/gravity//resources/gravity/low_step_size.gif)

You can also make the step size negative, but I think that that's enough for another blog post.

### Negative mass

Just as you can make the step size negative, you can also make the density negative. You can probably guess that since two positive masses attract, two negative masses repel.

![](/resources/gravity/negative_mass.gif)

When you have one positive mass and one negative mass, the result is kind of unexpected, but it also makes complete sense.

![](/resources/gravity/positive_negative.gif)

The positive mass still attracts, and the negative mass still repels, so they make a train that continually accelerates from the negative mass to the positive one. Some theories say that dark matter has negative mass, and that's why the universe is expanding.

### Different Integrators

I learned a bit about computational integration from this project. When I realized that elliptical orbits shouldn't change their angle, I understood how far off my integration was. At the time, I was using simple Euler integration, which means that I was simply adding the acceleration to the velocity and adding the velocity to the position at each time step. The higher the time step is, the higher the error is, since it doesn't compensate for the acceleration that the planet undergoes during the time step. It's like a 1st degree taylor approximation of the actual path.

There are many methods besides Euler's for computational integration. Pretty much all of them are more accurate, but also a lot harder to implement. The best solution for my project, from some research, was Verlet Integration. Instead of simply adding the velocity to the position, I used these equations (images from Wikipedia):

![](https://wikimedia.org/api/rest_v1/media/math/render/svg/61a7664efb9226850022e1fc675a53f902bdb8cd)

![](https://wikimedia.org/api/rest_v1/media/math/render/svg/596f01199cdb9b5bb35c5bf04ac54477cd085011)

Basically, Verlet integration assumes that the acceleration is constant and adds the integral of the velocity over the timestep to the velocity at the start of the timestep. This makes it 100% accurate if the acceleration is constant, which it's not.

Here's the difference between Verlet and Euler integration:

![](/resources/gravity/verlet.gif) 
![](/resources/gravity/euler.gif)

You can see that the error for Euler integration builds up much faster, but also that energy is not conserved. Whereas Verlet integration's error led to the ellipse rotating, Euler integration's error causes the orbit to gradually become wider.

### Dual Star System

![](/resources/gravity/dual_star.gif)

You can make dual star systems, and if you're lucky they'll be stable. You can also do fancy stuff like nested orbits, but it's pretty difficult. I'm planning on adding presets that you can just click a few buttons to add in because it's such a pain to make them.

