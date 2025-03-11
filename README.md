# EQ-zone-and-model-tools

EQG weapon model importer was originally created by Zaela. I have only improved it's functionality.

Improvements made:
1. Fixed application crashing on:
   - Importing new OBJ into EQG directory
   - Updating material properties
   - Adding new material properties
   - Adding emission points
   - Updating emission values
   - Adding particle points
   - Updating particle values
  
2. Added remove button to:
   - Material properties
   - Emission Points.
   - Attached Particles
  
3. Added math to rotational values from degrees to EQ expected out to make it more user friendly.
4. Swapped Translational values of Z and X (in gui only) to align with axis in blender to make placement more user friendly.


TO DO:
1. Add drop down menu for adding shader effects (change the lable on the field to Shader type).
2. Remove Property name field and add more options to Add Property button.
3. Remove export and import .ply (no materials so limited use)
4. Auto generate emission point names, Example: IT12345_POINT1, IT12345_POINT2, etc..

Aspirational Goals
1. Add support to pull material properties from a text file generated by blender addon.
2. Improve model viewer and include partile effects.
3. Add export to OBJ support with MTL.

     
