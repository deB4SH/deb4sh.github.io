---
title: Astrophotography - Into into ocular calculations
date: 2023-05-29 00:00
comments: false
tags:
- astrophotography
- astro
- photography
- telescope
- astrofotographie
---

>NOTE: This writeup is a knowledge dump of me to write down learnings from getting into astrophotography. Read everything with a grain of salt and please consider doing own research in this topic if my calculations may seem to be wrong. Thanks!

Hi there! 
Since some of you may already know, I bought an entry-level telescope to take a dive into astrophotography.
As my first telescope and tripod I went with an EQ3-2 Sky-Watcher and a 750/150 Omegon telescope.
The first steps to get the feet wet are always to simply take a look through an ocular and watch the stars.
Most bundles come with a set of small oculars, which should serve fine for the first months of observation.

The next step may be to buy bigger and better oculars for a more detailed observation. 
Before buying new expensive equipment it may be useful to calculate the range of possible magnification for your telescope to not waste money.


To start with the minimal possible magnification you could apply the following formular.

<center>
{% mathjax %}
V_{t_{min}} = \frac{d_{ep}}{7mm}
{% endmathjax %}
</center>

| Variable | | Description |
|--|--|--|
| {% mathjax %}V_{t_{min}}{% endmathjax %} | | minimal magnification |
| {% mathjax %}d_{ep}{% endmathjax %} | | Diameter of your entry pupil - eg. main mirror size for mirror telescops |
| {% mathjax %}7mm{% endmathjax %} | | Diameter of the human pupil [Source: National Library of Medicine](https://www.ncbi.nlm.nih.gov/books/NBK381/)|

Based on my telescope I need to take the 150mm of the primary mirror and divide it with the 7mm of a human pupil which results in a {% mathjax %}V_{t_{min}}{% endmathjax %} of 21.42. Which means the minimal *senseful* magnification is 21 for my 750/150 Omegon.

<center>
{% mathjax %}
V_{t_{min}} = \frac{150mm}{7mm} = 21.42
{% endmathjax %}
</center>

Based on this calculation, it is now possible to calculate the focal length of an ocular with this equation.

<center>
{% mathjax %}
f_{o} = \frac{f_{t}}{V_{t}}
{% endmathjax %}
</center>

| Variable | | Description |
|--|--|--|
| {% mathjax %}f_{t}{% endmathjax %} | | focal length telescope |
| {% mathjax %}V_{t}{% endmathjax %} | | magnification value |
| {% mathjax %}f_{o}{% endmathjax %} | | focal length ocular |

For my specific usecase this results into the following equation.

<center>
{% mathjax %}
f_{o} = \frac{750mm}{21.42} = 35.014mm
{% endmathjax %}
</center>

This means a 35mm ocular is biggest *senseful* focal length that can be applied to my telescope.

Next step is to calculate the optimal focal length for an ocular. 

<center>
{% mathjax %}
V_{t_{opt}} = \frac{d_{ep}}{0.7mm} = V_{t_{min}} * 10 = 214.2 
{% endmathjax %}
</center>

Replacing the variables within the equation for the focal length of an ocular results in 3.5mm focal for an optimal magnification.

<center>
{% mathjax %}
f_{o} = \frac{750mm}{214.2} = 3.5014mm
{% endmathjax %}
</center>

At last it may be useful to calculate the maximal magnification with the following equation.

<center>
{% mathjax %}
V_{t_{min}} = \frac{d_{ep}}{0.5mm} = d_{ep} * 2
{% endmathjax %}
</center>

The maximum resulting magnification for my telescope is around 300 which would result in a focal length of 2.5mm

<center>
{% mathjax %}
f_{o} = \frac{750mm}{300} = 2.5mm
{% endmathjax %}
</center>

#### Conclusion
With these values in mind, it is easier to search for good oculars and don't waste money on higher focal lengths that may not help get a clear and sharp image of the observed sky section.