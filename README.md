<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

WIP: Streaming driver for Fauna written in Dart. Can be used in Flutter or pure Dart projects.

## Features

-   Query based operations
-   Basic streaming operations

## WIP

-   Removing items from a set stream
-   Updating items in a set stream
-   Web streams, currently it runs a query once and then returns the results. This is not a streaming operation. There are ways to do this with the JS library that Fauna provides out, but the platform channel needs to be setup and the JS library needs to be imported. This is a WIP.
