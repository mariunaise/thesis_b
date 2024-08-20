#import "@preview/glossarium:0.4.1": *

= Boundary Adaptive Clustering with Helper Data

Instead of generating helper-data to improve the quantization process itself, like in #gls("smhdt"), or using some kind of error correcting code after the quantization process, we can also try to find helper-data before performing the quantization that will optimize our input values before quantizing them to minimize the risk of bit and symbol errors during the reconstruction phase. 

Since this #gls("hda") modifies the input values before the quantization takes place, we will consider the input values as zero-mean Gaussian distributed and not use a CDF to transform these values into the tilde-domain.

== Optimizing a 1-bit sign-based quantization<sect:1-bit-opt>

Before we take a look at the higher order quantization cases, we will start with a very basic method of quantization: a quantizer, that only returns a symbol with a width of $1$ bit and uses the sign of the input value to determine the resulting bit symbol.

#figure(
  include("./../graphics/quantizers/bach/sign-based-overlay.typ"),
  caption: [1-bit quantizer with the PDF of a normal distribution]
)<fig:1-bit_normal>

If we overlay the PDF of a zero-mean Gaussian distributed variable $X$ with a sign-based quantizer function as shown in @fig:1-bit_normal, we can see that the expected value of the Gaussian distribution overlaps with the decision threshold of the sign-based quantizer.
Considering that the margin of error of the value $x$ is comparable with the one shown in @fig:tmhd_example_enroll, we can conclude that values of $X$ that reside near $0$ are to be considered more unreliable than values that are further away from the x-value 0.
This means that the quantizer used here is very unreliable without generated helper-data.

Now, to increase the reliability of this quantizer, we can try to move our input values further away from the value $x = 0$. 
To do so, we can define a new input value $z$ as a linear combination of two realizations of $X$, $x_1$ and $x_2$ with a set of weights $h_1$ and $h_2$: 
$
z = h_1 dot x_1 + h_2 dot x_2 .
$<eq:lin_combs>

=== Derivation of the resulting distribution

To find a description for the random distribution $Z$ of $z$ we can interpret this process mathematically as a maximisation of a sum.
This can be realized by replacing the values of $x_i$ with their absolute values as this always gives us the maximum value of the sum:
$
z = abs(x_1) + abs(x_2) 
$
Taking into account, that $x_i$ are realizations of a normal distribution -- that we can assume without loss of generality to have its expected value at $x=0$ and a standard deviation of $sigma = 1$ -- we can define the overall resulting random distribution $Z$ to be: 
$
Z = abs(X) + abs(X).
$<eq:z_distribution>
We will redefine $abs(X)$ as a half-normal distribution $Y$ whose PDF is
$
f_Y(y, sigma) &= frac(sqrt(2), sigma sqrt(pi)) lr(exp(-frac(y^2, 2 sigma^2)) mid(|))_(sigma = 1), y >= 0 \
&= sqrt(frac(2, pi)) exp(- frac(y^2, sigma^2)) .
$<eq:half_normal>
Now, $Z$ simplifies to 
$
Z = Y + Y.
$
We can assume for now that the realizations of $Y$ are independent of each other.
The PDF of the addition of these two distributions can be described through the convolution of their respective PDFs: 
$
f_Z(z) &= integral_0^z f_Y (y) f_Y (z-y) \dy\
&= integral_0^z [sqrt(2/pi) exp(-frac(y^2,2)) sqrt(2/pi) exp(-frac((z-y)^2, 2))] \dy\
&= 2/pi integral_0^z exp(- frac(y^2 + (z-y)^2, 2)) \dy #<eq:z_integral>
$
Evaluating the integral of @eq:z_integral, we can now describe the resulting distribution of this maximisation process analytically:
$
f_Z = 2/sqrt(pi) exp(-frac(z^2, 4)) "erf"(z/2) z >= 0.
$<eq:z_result>
Our derivation of $f_Z$ currently only accounts for the addition of positive values of $x_i$, but two negative $x_i$ values would also return the maximal distance to the coordinate origin.
The derivation for the corresponding PDF is identical, except that the half-normal distribution @eq:half_normal is mirrored around the y-axis.
Because the resulting PDF $f_Z^"neg"$ is a mirrored variant of $f_Z$ and $f_Z$ is arranged  symmetrically around the origin, we can define a new PDF $f_Z^*$ as 
$
f_Z^* (z) = abs(f_Z (z)),
$
on the entire z-axis.
$f_Z^* (z)$ now describes the final random distribution after the application of our optimization of the input values $x_i$.
#figure(
  include("../graphics/plots/z_distribution.typ"),
  caption: [Optimized input values $z$ overlaid with sign-based quantizer $cal(Q)$]
)<fig:z_pdf>

@fig:z_pdf shows two key properties of this optimization:
1. Adjusting the input values using the method described above does not require any adjustment of the decision threshold of the sign-based quantizer.
2. The resulting PDF is zero at $z = 0$ leaving no input value for the sign-based quantizer at its decision threshold. 

=== Generating helper-data

To find the optimal set of helper-data that will result in the distribution shown in @fig:z_pdf, we can define the vector of all possible linear combinations $bold(z)$ as the vector-matrix multiplication of the two input values $x_i$ and the matrix $bold(H)$ of all weight combinations: 
$
bold(z) &= bold(x) dot bold(H)\
&= vec(x_1, x_2) dot mat(delim: "[", h_1, -h_1, h_1, -h_1; h_2, h_2, -h_2, -h_2)\
&= vec(x_1, x_2) dot mat(delim: "[", +1, -1, +1, -1; +1, +1, -1, -1)
$
We will choose the optimal weights based on the highest absolute value of $bold(z)$, as that value will be the furthest away from $0$. 
We may encounter two entries in $bold(z)$ that both have the same highest absolute value.
In that case, we will choose the combination of weights randomly out of our possible options. 

If we take a look at the dimensionality of the matrix of all weight combinations, we notice that we will need to store $log_2(2) = 1$ helper-data bit.
In fact, we will show later, that the amount of helper-data bits used by this HDA is directly linked to the number of input values used instead of the number of bits we want to extract during quantization.

== Generalization to higher-order bit quantization

We can generalize the idea of @sect:1-bit-opt and apply it for a higher-order bit quantization.
Contrary to @smhdt, we will always use the same step function as quantizer and optimize the input values $x$ to be the furthest away from any decision threshold.
In this higher-order case, this means that we want to optimise out input values as close as possible to the middle of a quantizer step or as far away as possible from the nearest decision threshold of the quantizer instead of just maximising the absolute value of the linear combination.

Two different strategies to find the linear combination arise from this premise: 
1. *Center point approximation*: Finding the linear combination that best approximates the center of a quantizer step, since these points are the furthest away from any decision threshold.
2. *Maximum quantizing bound distance approximation*:Approximating the point that is the furthest away directly through finding the linear combination with the maximum minimum distance to a decision threshold.

Although different in there respective implementations, both of these strategies aim to find a combination of helper-data that will best approximate one point out of a set of optimal points for $z$.
Thus we will define a vector $bold(cal(o)) in.rev {cal(o)_1, cal(o)_2 ..., cal(o)_(2^M)}$ containing the optimal values that we want to approximate with $z$.
Its cardinality is $2^M$, while $M$ defines the number of bits we want to extract through the quantization.
It has to be noted, that $bold(cal(o))$ consists of optimal values that we may not be able to exactly approximate using a linear combination based on weights and our given input values. 

In comparison to the 1-bit sign-based quantization, a linear combination with only two addends does not achieve sufficiently accurate results. 
Therefore, we will use three or more summands for the linear combination as this give us more flexible control over the result of the linear combination with the helper data. 
Later we will be able to show that a higher number of summands for $z$ can provide better approximations for the ideal values of $z$ at the expense of the number of available input values for the quantizer. 

We will define $z$ from now on as:
$
z = sum_(i=3)^n x_i dot h_i
$<eq:z_eq>

We can now find the optimal linear combination $z_"opt"$ by finding the minimum of all distances to all optimal points defined as $bold(cal(o))$.
The matrix that contains the distances of all linear combinations $bold(z)$ to all optimal points $bold(cal(o))$ is defined as: $bold(cal(A))$ with its entries $a_"ij" = abs(z_"i" - o_"j")$.\
$z_"opt"$ can now be defined as the minimal value in $bold(cal(A))$:
$
z_"opt" = op("argmin")(bold(cal(A)))
= op("argmin")(mat(delim: "[", a_("00"), ..., a_("i0"); dots.v, dots.down, " "; a_"0j", " ", a_"ij" )).
$
#figure(
  kind: "algorithm",
  supplement: [Algorithm],
  include("../pseudocode/bach_find_best_appr.typ")
)<alg:best_appr>

@alg:best_appr shows a programmatic approach to find the set of weights for the best approximation. The algorithm returns a tuple consisting of the weight combination $bold(h)$ and the resulting value of the linear combination $z_"opt"$
=== Realization of center point approximation

As described earlier, we can define the ideal possible positions for the linear combination $z_"opt"$ to be the centers of the quantizer steps.
Because the superposition of different linear combinations of normal distributions corresponds to a Gaussian Mixture Model, wherein finding the ideal set of points $bold(cal(o))$ analytically is impossible.

Instead, we will first estimate $bold(cal(o))$ based on the normal distribution parameters after performing multiple convolutions with the input distribution $X$.
The parameters of a multiple convoluted normal distribution is defined as: 
$
sum_(i=1)^(n) cal(N)(mu_i, sigma_i^2) tilde cal(N)(sum_(i=1)^n mu_i, sum_(i=1)^n sigma_i^2),
$
while $n$ defines the number of convolutions performed @schmutz.

With this definition, we can define the parameters of the probability distribution $Z$ of the linear combinations $z$ based on the parameters of $X$, $mu_X$ and $sigma_X$: 

$
Z(mu_Z, sigma_Z^2) = Z(sum_(i=1^n) mu_X, sum_(i=1)^n sigma_X^2)
$

The parameters $mu_Z$ and $sigma_Z$ allow us to apply an inverse CDF on a multi-bit quantizer $cal(Q)(2, tilde(x))$ defined in the tilde-domain. 
Our initial values for $bold(cal(o))_"first"$ can now be defined as the centers of the steps of the transformed quantizer function $cal(Q)(2, x)$.
These points can be found easily but for the outermost center points whose quantizer steps have a bound $plus.minus infinity$.\
However, we can still find these two remaining center points by artificially defining the outermost bounds of the quantizer as $frac(1, 2^M dot 4)$ and $frac((2^M dot 4)-1, 2^M dot 4)$ in the tilde-domain and also apply the inverse CDF to them. 

#scale(x: 90%, y: 90%)[
#figure(
  include("../graphics/quantizers/two-bit-enroll-real.typ"),
  caption: [Quantizer for the distribution resulting a triple convolution with distribution parameters $mu_X=0$ and $sigma_X=1$ with marked center points of the quantizer steps]
)<fig:two-bit-enroll-find-centers>]

We can now use an iterative algorithm that alternates between optimizing the quantizing bounds of $cal(Q)$ and our vector of optimal points $bold(cal(o))_"first"$.

#figure(
    kind: "algorithm",
    supplement: [Algorithm],
    include("../pseudocode/bach_1.typ")
)<alg:bach_1>

We can see both of these alternating parts in @alg:bach_1_2[Lines] and @alg:bach_1_3[] of @alg:bach_1. 
To optimize the quantizing bounds of $cal(Q)$, we will sort the values of all the resulting linear combinations $bold(z)_"opt"$ in ascending order. 
Using the inverse @ecdf defined in @eq:ecdf_inverse, we can find new quantizer bounds based on $bold(z)_"opt"$ from the first iteration.
These bounds will then be used to define a new set of optimal points $bold(cal(o))$ used for the next iteration. 
During every iteration of @alg:bach_1, we will store all weights $bold(h)$ used to generate the vector for optimal linear combinations $bold(z)_"opt"$. 

The output of @alg:bach_1 is the vector of optimal weights $bold(h)_"opt"$.
$bold(h)_"opt"$ can now be used to complete the enrollment phase and quantize the values $bold(z)_"opt"$.

To perform reconstruction, we can construct the same linear combination used during enrollment with the found helper-data and the new PUF readout measurements.

=== Maximum quantizing bound distance approximation

Instead of defining the optimal positions for $z$ $bold(cal(o))$ with fixed values, we can find the linear combination with the greatest distance to the nearest boundary.
This way, we will do things


== Experiments 

== Results & Discussion
