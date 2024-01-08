+++
title = "Bayes' Rule (in real life)"
date = Date("2023/07/17", "yyyy/mm/dd")
rss = ""
tags = ["math"]
+++
~~~
<details>
<summary>Table of Contents</summary>
~~~
\toc
~~~
</details>
~~~

# Motivating example

Let's say you're a doctor. A woman with no symptoms comes into your office after she's tested positive for breast cancer. Let's say the prevalence of breast cancer at her age is $1$ in $100$. Imagine we have a test that is $90\%$ accurate when the person has cancer and $91\%$ accurate when they don't have cancer.

We often refer to $90\%$ as the "sensitivity" (since it's how *sensitive* the test is to the disease). We call the $91\%$, "specificity", since it's how specific the test is for the disease.

The woman is stressed out that she tested positive. She asks you, "How likely is it that I have breast cancer?" **Is the answer 10% or 90%**? Many people make the mistake of saying $90\%$. The actual probability is $10\%$. This article will explain why, and how to avoid this mistake.

# A perspective on why this is wrong

My dad came up with a great way to think about it. Imagine a population of 1000 people and do the calculations on that. You know the prior is $1\%$, so $10$ people have cancer, and $990$ people don't. Our test is $90\%$ accurate when they have cancer; so, $9$ people who have cancer test positive, and $1$ person who has cancer tests negative. Of the $990$, our test is $91\%$ accurate, so about $901$ people test negative, and about $89$ people test positive.

We know the woman tested positive, so she is either one of $9$ who has it, or $89$ who doesn't have it. $\frac{9}{9+89}\approx \frac{1}{11}$ so she is about $10\%$ likely to have cancer. That was a lot of calculation, and directly applying Bayes' rule isn't much simpler. We will create a framework for making these kinds of decisions that is mathematically sound, and easy to use in real life, even if you don't like [math](/404).

# An aside about odds

You may have heard your friends bet on something with $1:1$ odds (or even odds). This means the event has a $50\%$ chance of happening. It is similar to the idea of "parts" in a cooking recipe, "3 parts water" and "2 parts wine" means the mixture will be $2:3=\frac{2}{5}=40\%$ wine. It's exactly the same happening here. $1:1$ is $50\%$, $1:2$ is about $33.3\%$, $1:3$ odds are $25\%$. The idea is to go from the odds of: "it happens $n$ times": "it happens $m$ times", we go $$n:m = \frac{\text{times it happens}}{\text{all the times}}=\frac{n}{n+m}.$$
This is how you can convert odds to probability.

You can convert probability to odds using the following formula. Let's say the probability of an event $A$ happening is $P(A)$. The odds of it happening are $P(A):P(\text{not } A).$

One nice thing about odds is you can cancel out common factors, so $2:4=1:2.$

# How do we fix our intuition?

You should think about the test---not as *determining* if she has breast cancer---but as *updating* your guess that she has breast cancer. Since the prevalence of breast cancer at her age (with no symptoms) is $1\%,$ she has the odds of breast cancer of $1:99$.

Now, apply this formula (with $O$ representing odds): $$O_{new} = O_{old}O_{evidence}.$$
So, $$O_{new} = O_{old}O_{pos}= (1:99)(10:1) = 10:99 \approx \frac{1}{11}=0.09090909.$$ Thus, the chance that she has the disease is $10:99,$ about $\textbf{9\%}$. This is the key formula that you should use in your everyday life. It allows to you quickly incorporate more evidence into your calculation, or change your prior odds.

Where the hell does this come from? Don't worry, I will explain.

# You ask: Why is the formula you presented remotely true???

Intuitively, think about the [waterfall analogy](https://arbital.com/p/bayes_rule/?l=693)

@@im-full
![wide vs narrow waterfall](https://i.imgur.com/6FOndjc.png?0)
@@

If the only thing we care about is the odds at the end (i.e. the ratio of red to blue at the bottom), then we only need to care about the odds that it goes in, $90:30$ or $45:15.$ Since they are the same odds, we end up with $3:4$ red to blue in both cases.

# The proof

We start with our prior odds, cancer:not cancer, which is written $O_{old}=P(C):P(\lnot C).$ 

We want to know the probability of **cancer** *given* she **is positive**. In probability form, we write that $P(C\mid +).$ This kind of conditional probability is really important to understand, and I can't explain it too thoroughly here, but the idea is when you say "A given B", you are restricting your universe of possible events to only ones where B is true, and you're asking, out of those times, how often is A true. That is, $P(A\mid B) = \frac{P(A\cap B)}{P(B)}.$ We can rewrite this as $P(A\mid B)P(B) = P(A\cap B)$. This formula will be very important. You should also know that we can rename the A's to B's, so $P(B\mid A)P(A) = P(B\cap A)=P(A \cap B)$. We will use this later.

The odds we want to know about can be written $O_{new} = P(C\mid +):P(\lnot C\mid +)$. This will tell us our new estimate of the likelihood that the woman has cancer, given that she tested positive.

I claim that the question mark is true. 

$$
\begin{align*}
&O_{old}O_{pos}\\&=(P(C):P(\lnot C))\cdot \left(P(+\mid C):P(+\mid \lnot C)\right)\\ &\stackrel{?}{=} P(C\mid+):P(\lnot C\mid+)\\&=O_{new}
\end{align*}
$$

Here is the proof:
$$
\begin{align*}
(&P(C):P(\lnot C))\cdot \left(P(+\mid C):P(+\mid \lnot C)\right)\\&=P(C)P(+\mid C):P(\lnot C)P(+\mid \lnot C)\\
&= P(+\cap C):P(+\cap \lnot C) \\
&= P(+)P(C\mid +):P(+)P(\lnot C|+)\\
&= P(C\mid +):P(\lnot C|+)\\
\end{align*}
$$
---

The last wrinkle to that calculation I showed earlier is how to calculate $O_{pos}=P(+\mid C):P(+\mid \lnot C).$ The trick is that usually this is given to you or easy to calculate. $P(+\mid \lnot C)$ is the false positive rate, which if the test is $91\%$ accurate when they don't have cancer is $9\%$. And $P(+|C)$, which is the true positive rate, or sensitivity of the test, $90\%$. Thus, the $O_{pos}=90:9=10:1.$

It should be clear now, that $$O_{new} = O_{old}O_{pos}= (1:99)(10:1) = 10:99 \approx 9.2\%.$$
This formula is amazing because it is very easy to add more evidence to update your understanding.

Let's say you reassure the woman. "It was a routine checkup, you have no symptoms, we just need to run another test, it was probably a mistake." She does it again and comes back positive again. Now, she should start to get worried: $$O_{newer}=O_{new}O_{pos}=(10:99)(10:1)=(100:99)\approx 50\%.$$
Almost even odds. Okay, sure, but let's imagine that the second test came back negative. To understand the odds, we need to calculate the odds for a negative test. **Try this on your own and I'll see you in the next paragraph.**

Now, let's calculate this, $$O_{neg}=P(-\mid C):P(-\mid \lnot C)=10:91.$$
This isn't as nice and round a  number, but it allows us to calculate:
$$O = O_{old}O_{pos}O_{neg}=(1:99)(10:1)(10:91)=100:9009 \approx 1\%$$
Another great thing about this, is let's say we get more information that the prevalence in her age group is actually $1:10$. How do we incorporate that? Well, it replaces our prior estimate. So, $O_{old} = 1:10$ rather than $1:99$. Now,
$$
\begin{align*}
O_{old}O_{pos} &=(1:10)(10:1)=10:10=50\%\\
O_{old}O_{pos}O_{pos} &=(1:10)(10:1)(10:1)=100:1=99\%\\
O_{old}O_{pos}O_{neg} &=(1:10)(10:1)(10:91)=100:910\approx10\%
.\end{align*}
$$


# Unrelated: What does multiplying odds usually do?

The rule $(n:m) \cdot (a:b) = an:mb,$ can be justified as follows:

$$
\begin{align*}
&(P(A):P(\lnot A))(P(B):P(\lnot B))\\
&= P(A)P(B):P(\lnot A)P(\lnot B)\\
&= P(A\cap B):P(\lnot A \,\cap \,\lnot B)\\
&= P(A\cap B):P(\lnot (A\cup B))
\end{align*}
$$
This might be better understood by a very poorly drawn PowerPoint slide: 

@@im-most
![](/assets/union-and-intersection.png)
@@

{{ addcomments }}
